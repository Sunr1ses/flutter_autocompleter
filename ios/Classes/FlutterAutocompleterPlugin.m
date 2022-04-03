#import "FlutterAutocompleterPlugin.h"
#if __has_include(<flutter_autocompleter/flutter_autocompleter-Swift.h>)
#import <flutter_autocompleter/flutter_autocompleter-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_autocompleter-Swift.h"
#endif

@implementation FlutterAutocompleterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterAutocompleterPlugin registerWithRegistrar:registrar];
}
@end
