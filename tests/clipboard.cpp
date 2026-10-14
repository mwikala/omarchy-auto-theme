#include <QClipboard>
#include <QGuiApplication>
#include <QMimeData>
#include <QQmlComponent>
#include <QQmlEngine>
#include <iostream>
#include <memory>

class Clipboard : public QMimeData {
public:
    mutable int reads = 0;
    QStringList formats() const override { return {"text/plain"}; }

protected:
    QVariant retrieveData(const QString &mime, QMetaType) const override {
        if (mime != "text/plain") return {};
        ++reads;
        return QString("Test city");
    }
};

int main(int argc, char **argv) {
    QGuiApplication application(argc, argv);
    QQmlEngine engine;
    QQmlComponent component(&engine);
    component.setData("import QtQuick\nTextInput { readOnly: true; visible: false }", QUrl());
    std::unique_ptr<QObject> field(component.create());
    if (!field) return 1;

    auto *readonly = new Clipboard;
    application.clipboard()->setMimeData(readonly);
    if (readonly->reads != 0) return 2;

    field->setProperty("readOnly", false);
    auto *editable = new Clipboard;
    application.clipboard()->setMimeData(editable);
    if (editable->reads == 0) return 3;

    field->setProperty("readOnly", true);
    auto *unfocused = new Clipboard;
    application.clipboard()->setMimeData(unfocused);
    if (unfocused->reads != 0) return 4;

    field.reset();
    auto *destroyed = new Clipboard;
    application.clipboard()->setMimeData(destroyed);
    if (destroyed->reads != 0) return 5;

    std::cout << "PASS: Qt " << qVersion()
              << " fetches clipboard text for hidden editable inputs, but not read-only or destroyed inputs\n";
}
