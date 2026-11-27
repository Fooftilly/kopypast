// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QObject>
#include <QUrl>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class BackupFile : public QObject
{
    Q_OBJECT
    QML_ELEMENT
public:
    explicit BackupFile(QObject *parent = nullptr) : QObject(parent) {}
    static constexpr qsizetype MaximumBytes = 16 * 1024 * 1024;
    Q_INVOKABLE QVariantMap read(const QUrl &url) const;
    // The caller must obtain explicit overwrite consent before passing true.
    Q_INVOKABLE QVariantMap write(const QUrl &url, const QString &text, bool replaceExisting) const;
};
