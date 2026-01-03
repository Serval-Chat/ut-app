import QtQuick 2.7
import Ubuntu.Components 1.3
import SerchatAPI 1.0

Page {
    id: debugPage
    header: PageHeader {
        id: header
        title: i18n.tr("Debug")
    }

    Column {
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: units.gu(2)
        }
        spacing: units.gu(2)

        Button {
            text: i18n.tr("Fetch User Profile")
            onClicked: {
                SerchatAPI.getUserProfile()
            }
        }

        TextArea {
            id: profileText
            width: parent.width
            height: parent.height - units.gu(6)
            readOnly: true
            placeholderText: i18n.tr("Profile data will appear here...")
        }
    }

    Connections {
        target: SerchatAPI
        onProfileFetched: {
            var json = JSON.stringify(profile, null, 2)
            profileText.text = json
        }
        onProfileFetchFailed: {
            profileText.text = "Error: " + error
        }
    }
}