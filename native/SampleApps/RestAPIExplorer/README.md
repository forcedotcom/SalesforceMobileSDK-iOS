# RestAPIExplorer

A native iOS sample app for the Salesforce Mobile SDK that lets you build and send Salesforce REST API requests and inspect the responses.

## Trying Native Login

RestAPIExplorer does not register a native login of its own. In debug builds (where `isDevSupportEnabled` is on), you can still try Native Login through the SDK's debug Login Options:

1. On the login screen, open **Login Options** from the menu (also available in the Dev Support menu).
2. Under **Authentication Mode**, select **Native**.
3. Enter the **Client ID**, **Native Callback URL** and **Community Login URL** of an External Client App that has Native Login (headless username-password flow) enabled. You can instead use **Import Native Login Configuration** to paste a JSON object with `consumerKey`, `redirectUri`, `communityUrl`, `useDPoP`, `useHybridFlow` and `authenticationMode`.
4. Optionally turn on **Use DPoP** or **Use Hybrid Authentication**. These apply to Native Login only and do not change the browser login options.
5. Close Login Options. Authentication restarts and shows the SDK's debug Native Login form. **Log In with Browser** falls back to the regular browser login.

Switching back to **Browser** mode restarts authentication with the regular browser login. The Native Login settings are stored separately from the browser login configuration. See [docs/auth/token-lifecycle.md](../../../docs/auth/token-lifecycle.md) ("Debug Native Login mode") for details.
