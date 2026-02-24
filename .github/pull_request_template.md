## Summary

-

## Testing

- [ ] `xcodebuild -project openauris.xcodeproj -scheme openauris -destination 'platform=macOS' build`
- [ ] `xcodebuild -project openauris.xcodeproj -scheme openauris -destination 'platform=macOS' -only-testing:openaurisTests test`

## Checklist

- [ ] Local-only behavior preserved (no cloud calls for transcription)
- [ ] New permissions are documented
- [ ] UI changes tested on light and dark appearance
