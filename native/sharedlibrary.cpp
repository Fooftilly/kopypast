// SPDX-License-Identifier: GPL-3.0-or-later
#include "sharedlibrary.h"
#include "backupfile.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLockFile>
#include <QRegularExpression>
#include <QStandardPaths>

namespace {
QVariantMap result(const QString &status)
{
    return {{QStringLiteral("status"), status}};
}

QString libraryPath(const QString &name)
{
    // Canonical, path-independent IDs; no aliases or directory traversal.
    static const QRegularExpression valid(QStringLiteral("\\A[a-z0-9][a-z0-9_-]{0,63}\\z"));
    if (!valid.match(name).hasMatch())
        return {};
    const auto root = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    if (root.isEmpty())
        return {};
    return QDir(root).filePath(QStringLiteral("io.github.fooftilly.kopypast/libraries/")
                               + name + QStringLiteral(".json"));
}

QString validateContent(const QString &text)
{
    if (text.size() > BackupFile::MaximumBytes)
        return QStringLiteral("too-large");
    if (!text.isValidUtf16())
        return QStringLiteral("invalid-utf16");
    const auto bytes = text.toUtf8();
    if (bytes.size() > BackupFile::MaximumBytes)
        return QStringLiteral("too-large");
    QJsonParseError error;
    const auto doc = QJsonDocument::fromJson(bytes, &error);
    if (error.error != QJsonParseError::NoError || !doc.isObject())
        return QStringLiteral("invalid-format");
    const auto object = doc.object();
    if (object.value(QStringLiteral("format")).toString() != QStringLiteral("io.github.fooftilly.kopypast")
            || object.value(QStringLiteral("version")).toDouble() != 1
            || !object.value(QStringLiteral("snippets")).isArray())
        return QStringLiteral("invalid-format");
    // Full record validation belongs to the existing QML model; do not
    // create a second implementation of the snippet schema here.
    return QStringLiteral("ok");
}

QString revision(const QString &text)
{
    return QString::fromLatin1(QCryptographicHash::hash(text.toUtf8(), QCryptographicHash::Sha256).toHex());
}

QVariantMap snapshot(const QString &path)
{
    const QFileInfo info(path);
    if (!info.exists() && !info.isSymLink())
        return result(QStringLiteral("missing"));
    BackupFile io;
    auto value = io.read(QUrl::fromLocalFile(path));
    if (value.value(QStringLiteral("status")).toString() != QStringLiteral("ok"))
        return value;
    const auto text = value.value(QStringLiteral("text")).toString();
    const auto status = validateContent(text);
    if (status != QStringLiteral("ok")) {
        // Preserve readable invalid data for explicit recovery/export.
        value.insert(QStringLiteral("status"), status);
        return value;
    }
    value.insert(QStringLiteral("revision"), revision(text));
    return value;
}

QVariantMap writeSnapshot(const QString &path, const QString &text, bool replace)
{
    BackupFile io;
    auto value = io.write(QUrl::fromLocalFile(path), text, replace);
    if (value.value(QStringLiteral("status")).toString() == QStringLiteral("ok"))
        value.insert(QStringLiteral("revision"), revision(text));
    return value;
}

QVariantMap lockFailure(const QLockFile &lock)
{
    return result(lock.error() == QLockFile::LockFailedError
                  ? QStringLiteral("busy") : QStringLiteral("lock-failed"));
}
}

SharedLibrary::SharedLibrary(QObject *parent) : QObject(parent)
{
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(50);
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] {
        m_debounce.start();
    });
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] {
        // Atomic replacement drops the old inode watch. Directory events
        // also cover deletion and recreation of the selected file.
        m_debounce.start();
    });
    connect(&m_debounce, &QTimer::timeout, this, &SharedLibrary::notifyChange);
}

bool SharedLibrary::watchLibrary(const QString &name)
{
    stopWatching();
    const auto path = libraryPath(name);
    if (path.isEmpty())
        return false;
    const auto directory = QFileInfo(path).absolutePath();
    if (!m_watcher.addPath(directory))
        return false;
    const QFileInfo info(path);
    if (info.isSymLink() || (info.exists() && (!info.isFile() || !m_watcher.addPath(path)))) {
        stopWatching();
        return false;
    }
    m_name = name;
    m_path = path;
    emit watchedLibraryChanged();
    return true;
}

void SharedLibrary::stopWatching()
{
    m_debounce.stop();
    const bool changed = !m_name.isEmpty();
    m_name.clear();
    m_path.clear();
    const auto paths = m_watcher.files() + m_watcher.directories();
    if (!paths.isEmpty())
        m_watcher.removePaths(paths);
    if (changed)
        emit watchedLibraryChanged();
}

void SharedLibrary::notifyChange()
{
    if (m_name.isEmpty())
        return;
    const QFileInfo info(m_path);
    // Reattach after QSaveFile replaces the watched inode. A missing file
    // remains covered by its directory watch.
    if (info.isFile() && !info.isSymLink() && !m_watcher.files().contains(m_path))
        m_watcher.addPath(m_path);
    emit snapshotChanged(m_name);
}

QVariantMap SharedLibrary::readSnapshot(const QString &name) const
{
    const auto path = libraryPath(name);
    if (path.isEmpty())
        return result(QStringLiteral("invalid-name"));
    // Atomic replacement gives readers either the previous or new snapshot.
    // Writers coordinate via the same per-library lock.
    return snapshot(path);
}

QVariantMap SharedLibrary::create(const QString &name, const QString &content) const
{
    const auto path = libraryPath(name);
    if (path.isEmpty())
        return result(QStringLiteral("invalid-name"));
    const auto status = validateContent(content);
    if (status != QStringLiteral("ok"))
        return result(status);
    if (!QDir().mkpath(QFileInfo(path).absolutePath()))
        return result(QStringLiteral("write-failed"));

    QLockFile lock(path + QStringLiteral(".lock"));
    // Never expire a lock held by a live process merely because of elapsed time.
    lock.setStaleLockTime(0);
    if (!lock.tryLock(0))
        return lockFailure(lock);
    const QFileInfo info(path);
    if (info.exists() || info.isSymLink())
        return result(QStringLiteral("exists"));
    return writeSnapshot(path, content, false);
}

QVariantMap SharedLibrary::commit(const QString &name, const QString &expectedRevision,
                                  const QString &content) const
{
    const auto path = libraryPath(name);
    if (path.isEmpty())
        return result(QStringLiteral("invalid-name"));
    const auto status = validateContent(content);
    if (status != QStringLiteral("ok"))
        return result(status);
    if (!QFileInfo(path).dir().exists())
        return result(QStringLiteral("missing"));

    QLockFile lock(path + QStringLiteral(".lock"));
    lock.setStaleLockTime(0);
    if (!lock.tryLock(0))
        return lockFailure(lock);
    const auto current = snapshot(path);
    if (current.value(QStringLiteral("status")).toString() != QStringLiteral("ok"))
        return current;
    if (current.value(QStringLiteral("revision")).toString() != expectedRevision)
        return result(QStringLiteral("conflict"));
    if (current.value(QStringLiteral("text")).toString() == content)
        return {{QStringLiteral("status"), QStringLiteral("ok")}, {QStringLiteral("revision"), expectedRevision}};
    return writeSnapshot(path, content, true);
}
