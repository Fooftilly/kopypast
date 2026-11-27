// SPDX-License-Identifier: GPL-3.0-or-later
#include "backupfile.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QStringDecoder>
#include <QTemporaryFile>

namespace {
QVariantMap result(const QString &status)
{
    return {{QStringLiteral("status"), status}};
}

QString localPath(const QUrl &url)
{
    if (!url.isLocalFile() || !url.host().isEmpty() || url.hasQuery() || url.hasFragment())
        return {};
    const auto path = url.toLocalFile();
    return QDir::isAbsolutePath(path) ? path : QString();
}
}

QVariantMap BackupFile::read(const QUrl &url) const
{
    const auto path = localPath(url);
    if (path.isEmpty())
        return result(QStringLiteral("invalid-path"));
    const QFileInfo info(path);
    if (!info.isFile() || info.isSymLink())
        return result(QStringLiteral("invalid-path"));
    if (info.size() > MaximumBytes)
        return result(QStringLiteral("too-large"));
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return result(QStringLiteral("read-failed"));
    const auto bytes = file.read(MaximumBytes + 1);
    if (file.error() != QFileDevice::NoError)
        return result(QStringLiteral("read-failed"));
    if (bytes.size() > MaximumBytes || !file.atEnd())
        return result(QStringLiteral("too-large"));

    QStringDecoder decoder(QStringDecoder::Utf8);
    const QString text = decoder(bytes);
    if (decoder.hasError())
        return result(QStringLiteral("invalid-utf8"));
    return {{QStringLiteral("status"), QStringLiteral("ok")},
            {QStringLiteral("text"), text}};
}

QVariantMap BackupFile::write(const QUrl &url, const QString &text, bool replaceExisting) const
{
    const auto path = localPath(url);
    if (path.isEmpty())
        return result(QStringLiteral("invalid-path"));
    const QFileInfo info(path);
    if (info.isSymLink() || (info.exists() && !info.isFile()) || !info.dir().exists())
        return result(QStringLiteral("invalid-path"));
    if (info.exists() && !replaceExisting)
        return result(QStringLiteral("exists"));
    if (text.size() > MaximumBytes)
        return result(QStringLiteral("too-large"));
    const auto bytes = text.toUtf8();
    if (bytes.size() > MaximumBytes)
        return result(QStringLiteral("too-large"));
    const auto permissions = QFileDevice::ReadOwner | QFileDevice::WriteOwner;

    if (!replaceExisting) {
        // Create a private temporary file beside the destination. Qt's
        // QTemporaryFile::rename refuses to replace an existing destination.
        QTemporaryFile temp(info.dir().filePath(QStringLiteral(".kopypast-XXXXXX")));
        if (!temp.open() || !temp.setPermissions(permissions)
                || temp.write(bytes) != bytes.size() || !temp.flush())
            return result(QStringLiteral("write-failed"));
        temp.close();
        if (!temp.rename(path))
            return result(QFileInfo::exists(path) ? QStringLiteral("exists") : QStringLiteral("write-failed"));
        temp.setAutoRemove(false);
        return result(QStringLiteral("ok"));
    }

    // No direct-write fallback: preserve the old file if atomic commit fails.
    QSaveFile file(path);
    file.setDirectWriteFallback(false);
    if (!file.open(QIODevice::WriteOnly))
        return result(QStringLiteral("write-failed"));
    if (!file.setPermissions(permissions) || file.write(bytes) != bytes.size()) {
        file.cancelWriting();
        return result(QStringLiteral("write-failed"));
    }
    return result(file.commit() ? QStringLiteral("ok") : QStringLiteral("write-failed"));
}
