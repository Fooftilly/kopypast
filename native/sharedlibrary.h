// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QObject>
#include <QFileSystemWatcher>
#include <QTimer>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class SharedLibrary : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    // Name of the one library this instance watches, or empty.
    Q_PROPERTY(QString watchedLibrary READ watchedLibrary NOTIFY watchedLibraryChanged)
public:
    explicit SharedLibrary(QObject *parent = nullptr);
    Q_INVOKABLE QVariantMap readSnapshot(const QString &name) const;
    Q_INVOKABLE QVariantMap create(const QString &name, const QString &content) const;
    Q_INVOKABLE QVariantMap commit(const QString &name, const QString &expectedRevision,
                                  const QString &content) const;
    // Notifications are hints; a reader must check the revision again.
    Q_INVOKABLE bool watchLibrary(const QString &name);
    Q_INVOKABLE void stopWatching();
    QString watchedLibrary() const { return m_name; }
signals:
    void snapshotChanged(const QString &name);
    void watchedLibraryChanged();
private:
    void notifyChange();
    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
    QString m_name;
    QString m_path;
};
