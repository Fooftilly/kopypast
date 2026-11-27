// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QObject>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class SharedLibrary : public QObject
{
    Q_OBJECT
    QML_ELEMENT
public:
    explicit SharedLibrary(QObject *parent = nullptr) : QObject(parent) {}
    Q_INVOKABLE QVariantMap readSnapshot(const QString &name) const;
    Q_INVOKABLE QVariantMap create(const QString &name, const QString &content) const;
    Q_INVOKABLE QVariantMap commit(const QString &name, const QString &expectedRevision,
                                  const QString &content) const;
};
