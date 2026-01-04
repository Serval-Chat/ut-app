import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3

import SerchatAPI 1.0
import "components" as Components

Page {
    id: loginPage
    
    // Hide header for cleaner login screen
    header: Item { height: 0 }
    
    property bool isLoginMode: true
    property bool loading: false
    
    Rectangle {
        anchors.fill: parent
        color: Theme.palette.normal.background
    }

    Flickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + units.gu(8)
        clip: true
        
        ColumnLayout {
            id: contentColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: units.gu(3)
            }
            spacing: units.gu(2)
            
            Item { Layout.preferredHeight: units.gu(4) }
            
            // Logo/branding area
            Rectangle {
                Layout.preferredWidth: units.gu(12)
                Layout.preferredHeight: units.gu(12)
                Layout.alignment: Qt.AlignHCenter
                radius: units.gu(3)
                color: LomiriColors.blue
                
                Label {
                    anchors.centerIn: parent
                    text: "S"
                    font.pixelSize: units.gu(6)
                    font.bold: true
                    color: "white"
                }
            }
            
            Label {
                text: "Serchat"
                fontSize: "x-large"
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
            
            Label {
                text: isLoginMode ? 
                      i18n.tr("Welcome back! Sign in to continue.") :
                      i18n.tr("Create an account to get started.")
                fontSize: "small"
                color: Theme.palette.normal.backgroundSecondaryText
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            Item { Layout.preferredHeight: units.gu(2) }
            
            // Registration-only fields
            TextField {
                id: registerUsernameField
                placeholderText: i18n.tr("Username")
                Layout.fillWidth: true
                visible: !isLoginMode
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
            }

            TextField {
                id: usernameField
                placeholderText: isLoginMode ? i18n.tr("Email or Username") : i18n.tr("Email")
                Layout.fillWidth: true
                inputMethodHints: Qt.ImhEmailCharactersOnly
            }

            TextField {
                id: passwordField
                placeholderText: i18n.tr("Password")
                echoMode: TextInput.Password
                Layout.fillWidth: true
                
                onAccepted: {
                    if (isLoginMode) {
                        doLogin()
                    } else if (confirmPasswordField.text === passwordField.text) {
                        doRegister()
                    }
                }
            }
            
            TextField {
                id: confirmPasswordField
                placeholderText: i18n.tr("Confirm Password")
                echoMode: TextInput.Password
                Layout.fillWidth: true
                visible: !isLoginMode
            }
            
            TextField {
                id: inviteTokenField
                placeholderText: i18n.tr("Invite Token (optional)")
                Layout.fillWidth: true
                visible: !isLoginMode
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
            }

            // Error message
            Label {
                id: errorLabel
                text: ""
                color: LomiriColors.red
                visible: text !== ""
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            
            Item { Layout.preferredHeight: units.gu(1) }

            // Main action button
            Button {
                id: actionButton
                text: loading ? 
                      (isLoginMode ? i18n.tr("Signing in...") : i18n.tr("Creating account...")) :
                      (isLoginMode ? i18n.tr("Sign In") : i18n.tr("Create Account"))
                color: LomiriColors.blue
                Layout.fillWidth: true
                enabled: !loading && validateForm()
                
                onClicked: {
                    if (isLoginMode) {
                        doLogin()
                    } else {
                        doRegister()
                    }
                }
            }
            
            // Forgot password (login mode only)
            Label {
                text: i18n.tr("Forgot password?")
                fontSize: "small"
                color: LomiriColors.blue
                Layout.alignment: Qt.AlignHCenter
                visible: isLoginMode
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        // TODO: Implement password reset
                    }
                }
            }
            
            Item { Layout.preferredHeight: units.gu(2) }
            
            // Divider
            Row {
                Layout.fillWidth: true
                spacing: units.gu(2)
                
                Rectangle {
                    height: units.dp(1)
                    color: Theme.palette.normal.base
                    Layout.fillWidth: true
                    anchors.verticalCenter: parent.verticalCenter
                    width: (parent.width - orLabel.width - units.gu(4)) / 2
                }
                
                Label {
                    id: orLabel
                    text: i18n.tr("or")
                    fontSize: "small"
                    color: Theme.palette.normal.backgroundSecondaryText
                }
                
                Rectangle {
                    height: units.dp(1)
                    color: Theme.palette.normal.base
                    Layout.fillWidth: true
                    anchors.verticalCenter: parent.verticalCenter
                    width: (parent.width - orLabel.width - units.gu(4)) / 2
                }
            }
            
            Item { Layout.preferredHeight: units.gu(1) }
            
            // Toggle login/register
            Button {
                text: isLoginMode ? i18n.tr("Create New Account") : i18n.tr("Already have an account?")
                Layout.fillWidth: true
                
                onClicked: {
                    isLoginMode = !isLoginMode
                    errorLabel.text = ""
                }
            }
            
            Item { Layout.preferredHeight: units.gu(3) }
            
            // API settings link
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: units.gu(0.5)
                
                Label {
                    text: i18n.tr("Connecting to:")
                    fontSize: "x-small"
                    color: Theme.palette.normal.backgroundSecondaryText
                }
                
                Label {
                    text: SerchatAPI.apiBaseUrl
                    fontSize: "x-small"
                    color: LomiriColors.blue
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            pageStack.push(Qt.resolvedUrl("ApiSettingsPage.qml"))
                        }
                    }
                }
            }
            
            // Version
            Label {
                text: i18n.tr("Version %1").arg(Qt.application.version)
                fontSize: "x-small"
                color: Theme.palette.normal.backgroundSecondaryText
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
    
    // Loading overlay
    Components.LoadingOverlay {
        anchors.fill: parent
        visible: loading
        message: isLoginMode ? i18n.tr("Signing in...") : i18n.tr("Creating account...")
    }
    
    function validateForm() {
        if (isLoginMode) {
            return usernameField.text.trim().length > 0 && 
                   passwordField.text.length > 0
        } else {
            return registerUsernameField.text.trim().length > 0 &&
                   usernameField.text.trim().length > 0 && 
                   passwordField.text.length >= 6 &&
                   passwordField.text === confirmPasswordField.text
        }
    }
    
    function doLogin() {
        if (!validateForm()) return
        
        loading = true
        errorLabel.text = ""
        SerchatAPI.login(usernameField.text.trim(), passwordField.text)
    }
    
    function doRegister() {
        if (!validateForm()) return
        
        if (passwordField.text !== confirmPasswordField.text) {
            errorLabel.text = i18n.tr("Passwords do not match")
            return
        }
        
        if (passwordField.text.length < 6) {
            errorLabel.text = i18n.tr("Password must be at least 6 characters")
            return
        }
        
        loading = true
        errorLabel.text = ""
        SerchatAPI.registerUser(
            registerUsernameField.text.trim(),  // login
            registerUsernameField.text.trim(),  // username (same as login for now)
            passwordField.text,
            inviteTokenField.text.trim()
        )
    }

    Connections {
        target: SerchatAPI
        
        onLoginSuccessful: {
            loading = false
            pageStack.clear()
            pageStack.push(Qt.resolvedUrl("HomePage.qml"))
        }
        
        onLoginFailed: {
            loading = false
            errorLabel.text = reason
        }
        
        onRegisterSuccessful: {
            loading = false
            pageStack.clear()
            pageStack.push(Qt.resolvedUrl("HomePage.qml"))
        }
        
        onRegisterFailed: {
            loading = false
            errorLabel.text = reason
        }
    }
}
