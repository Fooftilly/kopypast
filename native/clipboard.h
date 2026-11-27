// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>

class Clipboard : public QObject
{
    Q_OBJECT
    QML_ELEMENT
public:
    explicit Clipboard(QObject *parent = nullptr) : QObject(parent) {}
    Q_INVOKABLE bool copyText(const QString &text) const;
};
