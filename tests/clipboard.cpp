#include <QClipboard>
#include <QGuiApplication>
#include <QMimeData>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickView>
#include <QQuickItem>
#include <QSignalSpy>
#include <QtTest>
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

void check(bool condition, const char *message) {
    if (condition) return;
    std::cerr << "FAIL: " << message << '\n';
    std::exit(1);
}

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

    QQuickView view;
    view.setSource(QUrl::fromLocalFile(QString::fromLocal8Bit(argv[1])));
    auto *entry = view.rootObject();
    check(entry, "actual Entry.qml must load");
    entry->setWidth(360);
    entry->setHeight(40);
    view.resize(360, 40);
    view.show();
    view.requestActivate();
    entry->forceActiveFocus();
    QCoreApplication::processEvents();
    check(entry->hasActiveFocus(), "entry must receive focus");
    check(entry->property("readOnly").toBool(), "focused entry must stay read-only");

    auto *foreign = new Clipboard;
    application.clipboard()->setMimeData(foreign);
    QCoreApplication::processEvents();
    check(foreign->reads == 0, "focused entry must not fetch foreign clipboard text");
    for (char letter : std::string("Paris")) QTest::keyClick(&view, letter);
    check(entry->property("text").toString() == "Paris", "typing must still work");
    QTest::keyClick(&view, Qt::Key_Backspace);
    check(entry->property("text").toString() == "Pari", "backspace must work");
    QTest::keyClick(&view, Qt::Key_Z, Qt::ControlModifier);
    check(entry->property("text").toString() == "Paris", "undo must work");
    QTest::keyClick(&view, Qt::Key_A, Qt::ControlModifier);
    QTest::keyClick(&view, 'L');
    check(entry->property("text").toString() == "L", "typing must replace the selection");
    QSignalSpy pastes(entry, SIGNAL(pasteRequested(bool)));
    QTest::keyClick(&view, Qt::Key_V, Qt::ControlModifier);
    check(pastes.count() == 1, "paste must request the bounded helper");
    QTest::keyClick(&view, Qt::Key_Insert, Qt::ShiftModifier);
    check(pastes.count() == 2, "Shift+Insert must request the bounded helper");
    QTest::mouseClick(&view, Qt::MiddleButton, Qt::NoModifier, QPoint(10, 10));
    check(pastes.count() == 3 && pastes.last().at(0).toBool(), "middle-click must request bounded primary selection");
    QMetaObject::invokeMethod(entry, "paste");
    check(foreign->reads == 0, "paste shortcut must not invoke native clipboard reads");
    QTest::keyClick(&view, Qt::Key_A, Qt::ControlModifier);
    QKeyEvent unicode(QEvent::KeyPress, Qt::Key_unknown, Qt::NoModifier, QString::fromUtf8("é"));
    QCoreApplication::sendEvent(&view, &unicode);
    check(entry->property("text").toString() == QString::fromUtf8("é"), "Unicode key text must work");
    QVariant accepted;
    QMetaObject::invokeMethod(entry, "replace", Q_RETURN_ARG(QVariant, accepted), Q_ARG(QVariant, QString(129, 'x')));
    check(!accepted.toBool(), "oversize edits must be rejected");
    entry->setFocus(false);
    QCoreApplication::processEvents();
    check(foreign->reads == 0, "blur must not fetch clipboard text");

    std::cout << "PASS: Qt " << qVersion() << "; actual Entry.qml stays read-only while typing, selecting, undoing and requesting paste; zero native clipboard reads\n";
}
