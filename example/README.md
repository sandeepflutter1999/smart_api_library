# smart_api example

A runnable demo of `smart_api` against the free [reqres.in](https://reqres.in)
API. It shows:

- `SmartApiConfig.init` with a custom `responseParser`
- `SmartApiHooks` wired to a loader overlay and a `SnackBar`
- A real GET and POST call through `SmartApiClient.instance`
- Simulating a no-internet retry and a 401 session-expiry

Run it from this folder:

```bash
flutter pub get
flutter run
```
