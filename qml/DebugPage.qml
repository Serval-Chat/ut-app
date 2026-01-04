import QtQuick 2.7
import Lomiri.Components 1.3
import SerchatAPI 1.0

Page {
    id: debugPage
    header: PageHeader {
        id: header
        title: i18n.tr("Debug")
    }

    Flickable {
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        contentHeight: contentColumn.height + units.gu(4)

        Column {
            id: contentColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: units.gu(2)
            }
            spacing: units.gu(2)

            // Authentication Section
            Label {
                text: i18n.tr("Authentication")
                font.bold: true
            }

            Row {
                spacing: units.gu(1)
                TextField {
                    id: loginField
                    width: units.gu(15)
                    placeholderText: i18n.tr("Login")
                }
                TextField {
                    id: passwordField
                    width: units.gu(15)
                    echoMode: TextInput.Password
                    placeholderText: i18n.tr("Password")
                }
            }

            Row {
                spacing: units.gu(1)
                Button {
                    text: i18n.tr("Login")
                    onClicked: {
                        SerchatAPI.login(loginField.text, passwordField.text)
                    }
                }
                Button {
                    text: i18n.tr("Logout")
                    onClicked: {
                        SerchatAPI.logout()
                    }
                }
                Button {
                    text: i18n.tr("Validate Token")
                    onClicked: {
                        SerchatAPI.validateAuthToken()
                    }
                }
            }

            // Profile Section
            Label {
                text: i18n.tr("Profile")
                font.bold: true
            }

            Row {
                spacing: units.gu(1)
                Button {
                    text: i18n.tr("Fetch User Profile")
                    onClicked: {
                        SerchatAPI.getUserProfile()
                    }
                }
                Button {
                    text: i18n.tr("Get My Profile")
                    onClicked: {
                        var requestId = SerchatAPI.getMyProfile()
                        appendLog("Requested profile with ID: " + requestId)
                    }
                }
            }

            // Servers Section
            Label {
                text: i18n.tr("Servers")
                font.bold: true
            }

            Row {
                spacing: units.gu(1)
                Button {
                    text: i18n.tr("Get Servers")
                    onClicked: {
                        var requestId = SerchatAPI.getServers()
                        appendLog("Requested servers with ID: " + requestId)
                    }
                }
                TextField {
                    id: serverIdField
                    width: units.gu(15)
                    placeholderText: i18n.tr("Server ID")
                }
                Button {
                    text: i18n.tr("Get Server Details")
                    onClicked: {
                        if (serverIdField.text) {
                            var requestId = SerchatAPI.getServerDetails(serverIdField.text)
                            appendLog("Requested server details with ID: " + requestId)
                        }
                    }
                }
            }

            // Channels Section
            Label {
                text: i18n.tr("Channels")
                font.bold: true
            }

            Row {
                spacing: units.gu(1)
                TextField {
                    id: channelServerIdField
                    width: units.gu(15)
                    placeholderText: i18n.tr("Server ID")
                }
                Button {
                    text: i18n.tr("Get Channels")
                    onClicked: {
                        if (channelServerIdField.text) {
                            var requestId = SerchatAPI.getChannels(channelServerIdField.text)
                            appendLog("Requested channels with ID: " + requestId)
                        }
                    }
                }
            }

            // Cache Section
            Label {
                text: i18n.tr("Cache")
                font.bold: true
            }

            Row {
                spacing: units.gu(1)
                Button {
                    text: i18n.tr("Clear Cache")
                    onClicked: {
                        SerchatAPI.clearCache()
                        appendLog("Cache cleared")
                    }
                }
                Button {
                    text: i18n.tr("Set Cache TTL 30s")
                    onClicked: {
                        SerchatAPI.setCacheTTL(30)
                        appendLog("Cache TTL set to 30 seconds")
                    }
                }
            }

            // Debug Info
            Label {
                text: i18n.tr("Debug Info")
                font.bold: true
            }

            Row {
                spacing: units.gu(1)
                Button {
                    text: i18n.tr("Enable Debug")
                    onClicked: {
                        SerchatAPI.setDebug(true)
                        appendLog("Debug enabled")
                    }
                }
                Label {
                    text: i18n.tr("Logged In: ") + (SerchatAPI.loggedIn ? "Yes" : "No")
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            TextArea {
                id: profileText
                width: parent.width
                height: units.gu(20)
                readOnly: true
                placeholderText: i18n.tr("API responses will appear here...")
            }
        }
    }

    function appendLog(message) {
        var timestamp = new Date().toLocaleTimeString()
        profileText.text += "[" + timestamp + "] " + message + "\n"
    }

    Connections {
        target: SerchatAPI

        // Authentication
        onLoginSuccessful: {
            appendLog("Login successful")
        }
        onLoginFailed: {
            appendLog("Login failed: " + reason)
        }
        onRegisterSuccessful: {
            appendLog("Registration successful")
        }
        onRegisterFailed: {
            appendLog("Registration failed: " + reason)
        }
        onAuthTokenInvalid: {
            appendLog("Auth token invalid")
        }
        onLoggedInChanged: {
            appendLog("Logged in status changed: " + SerchatAPI.loggedIn)
        }

        // Profile (simple)
        onProfileFetched: {
            var json = JSON.stringify(profile, null, 2)
            appendLog("Profile fetched:\n" + json)
        }
        onProfileFetchFailed: {
            appendLog("Profile fetch failed: " + error)
        }

        // Profile (with request ID)
        onMyProfileFetched: {
            var json = JSON.stringify(profile, null, 2)
            appendLog("My profile fetched:\n" + json)
        }
        onMyProfileFetchFailed: {
            appendLog("My profile fetch failed: " + error)
        }

        // Servers
        onServersFetched: {
            var json = JSON.stringify(servers, null, 2)
            appendLog("Servers fetched (ID: " + requestId + "):\n" + json)
        }
        onServersFetchFailed: {
            appendLog("Servers fetch failed (ID: " + requestId + "): " + error)
        }
        onServerDetailsFetched: {
            var json = JSON.stringify(server, null, 2)
            appendLog("Server details fetched (ID: " + requestId + "):\n" + json)
        }
        onServerDetailsFetchFailed: {
            appendLog("Server details fetch failed (ID: " + requestId + "): " + error)
        }

        // Channels
        onChannelsFetched: {
            var json = JSON.stringify(channels, null, 2)
            appendLog("Channels fetched for server " + serverId + " (ID: " + requestId + "):\n" + json)
        }
        onChannelsFetchFailed: {
            appendLog("Channels fetch failed for server " + serverId + " (ID: " + requestId + "): " + error)
        }
    }
}