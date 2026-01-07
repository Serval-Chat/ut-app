import QtQuick 2.7
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import SerchatAPI 1.0

Dialog {
    id: dialog
    title: i18n.tr("Change Username")
    text: i18n.tr("Enter your new username:")
    
    property string currentUsername: ""
    property bool working: false
    property int requestId: -1
    
    signal usernameChanged()
    
    TextField {
        id: usernameField
        placeholderText: i18n.tr("New username")
        text: currentUsername
        inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
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
        text: working ? i18n.tr("Changing...") : i18n.tr("Change Username")
        color: LomiriColors.blue
        enabled: !working && usernameField.text !== "" && usernameField.text !== currentUsername
        onClicked: {
            if (usernameField.text.trim() === "") {
                errorLabel.text = i18n.tr("Username cannot be empty")
                return
            }
            
            errorLabel.text = ""
            working = true
            requestId = SerchatAPI.changeUsername(usernameField.text.trim())
        }
    }
    
    Button {
        text: i18n.tr("Cancel")
        onClicked: PopupUtils.close(dialog)
    }
    
    Connections {
        target: SerchatAPI
        
        onProfileUpdateSuccess: function(reqId) {
            if (reqId === requestId) {
                working = false
                usernameChanged()
                PopupUtils.close(dialog)
            }
        }
        
        onProfileUpdateFailed: function(reqId, error) {
            if (reqId === requestId) {
                working = false
                errorLabel.text = error
            }
        }
    }
}
