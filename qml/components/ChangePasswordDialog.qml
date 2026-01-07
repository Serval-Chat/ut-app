import QtQuick 2.7
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import SerchatAPI 1.0

Dialog {
    id: dialog
    title: i18n.tr("Change Password")
    text: i18n.tr("Enter your current password and new password:")
    
    property bool working: false
    
    signal passwordChanged()
    
    TextField {
        id: currentPasswordField
        placeholderText: i18n.tr("Current password")
        echoMode: TextInput.Password
        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
        enabled: !working
    }
    
    TextField {
        id: newPasswordField
        placeholderText: i18n.tr("New password")
        echoMode: TextInput.Password
        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
        enabled: !working
    }
    
    TextField {
        id: confirmPasswordField
        placeholderText: i18n.tr("Confirm new password")
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
        text: working ? i18n.tr("Changing...") : i18n.tr("Change Password")
        color: LomiriColors.blue
        enabled: !working && currentPasswordField.text !== "" && newPasswordField.text !== "" && confirmPasswordField.text !== ""
        onClicked: {
            if (currentPasswordField.text === "") {
                errorLabel.text = i18n.tr("Current password is required")
                return
            }
            if (newPasswordField.text === "") {
                errorLabel.text = i18n.tr("New password cannot be empty")
                return
            }
            if (newPasswordField.text !== confirmPasswordField.text) {
                errorLabel.text = i18n.tr("Passwords do not match")
                return
            }
            if (newPasswordField.text.length < 6) {
                errorLabel.text = i18n.tr("Password must be at least 6 characters")
                return
            }
            
            errorLabel.text = ""
            working = true
            SerchatAPI.changePassword(currentPasswordField.text, newPasswordField.text)
        }
    }
    
    Button {
        text: i18n.tr("Cancel")
        onClicked: PopupUtils.close(dialog)
    }
    
    Connections {
        target: SerchatAPI
        
        onChangePasswordSuccessful: {
            working = false
            currentPasswordField.text = ""
            newPasswordField.text = ""
            confirmPasswordField.text = ""
            passwordChanged()
            PopupUtils.close(dialog)
        }
        
        onChangePasswordFailed: function(error) {
            working = false
            currentPasswordField.text = ""
            newPasswordField.text = ""
            confirmPasswordField.text = ""
            errorLabel.text = error
        }
    }
}
