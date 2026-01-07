This is a client/frontend for the Serchat chatting application. It is in many respects similar to Discord, but open-source. The app is designed to be convergent between phone-sized screens and desktop-sized screens.

The API is not stable; you can assume you do not need to support older versions of the backend when you make changes to API code. You can find a OpenAPI description of most of the HTTP-based API in `openapi.yaml`. There are also `*.dev.md` files in this repository, which contain information which was written by other agents, for the purposes of assisting with development. You may create and modify any such files at will, but do not insert any information you have not verified to be correct and true into them, for example, if you adjust documentation for a endpoint or a function in them, you must first verify that the information you wish to change or insert is correct.

You can reference the backend at the following URL: https://github.com/Serval-Chat/backend. You should always refer to the backend when a issue in relation to endpoints occurs, and information is missing from the `openapi.yaml` file.

You can run this project with `clickable desktop --no-nvidia`. NEVER try to manually run or compile this application without using clickable, it will never work. Additionally, do not run the application while only reading the `head` of the output, use `tail` instead.
