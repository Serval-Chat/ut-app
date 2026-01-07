import QtQuick 2.7
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import SerchatAPI 1.0

Dialog {
    id: dialog
    title: i18n.tr("Change Email/Login")
    text: i18n.tr("Enter your new email and current password:")
    
    property string currentEmail: ""
    property bool working: false
    
    signal emailChanged()
    
    TextField {
        id: emailField
        placeholderText: i18n.tr("New email")
        text: currentEmail
        inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoPredictiveText
        enabled: !working
    }
    
    TextField {
        id: passwordField
        placeholderText: i18n.tr("Current password")
        echoMode: TextInput.Password
        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
        enabled: !working
    }
    
    Label {
        id: errorLabel
        visible: text !== ""
        color: LomiriColors.red
        wrapMode: Text.Wrap
        width: parent.width
    }
    
    Button {
        text: working ? i18n.tr("Changing...") : i18n.tr("Change Email")
        color: LomiriColors.blue
        enabled: !working && emailField.text !== "" && passwordField.text !== "" && emailField.text !== currentEmail
        onClicked: {
            if (emailField.text.trim() === "") {
                errorLabel.text = i18n.tr("Email cannot be empty")
                return
            }
            if (passwordField.text === "") {
                errorLabel.text = i18n.tr("Password is required")
                return
            }
            
            errorLabel.text = ""
            working = true
            SerchatAPI.changeLogin(emailField.text.trim(), passwordField.text)
        }
    }
    
    Button {
        text: i18n.tr("Cancel")
        onClicked: PopupUtils.close(dialog)
    }
    
    Connections {
        target: SerchatAPI
        
        onChangeLoginSuccessful: {
            working = false
            passwordField.text = ""
            emailChanged()
            PopupUtils.close(dialog)
        }
        
        onChangeLoginFailed: function(error) {
            working = false
            passwordField.text = ""
            errorLabel.text = error
        }
    }
}
