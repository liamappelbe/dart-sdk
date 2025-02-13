// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/error/error.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/src/pubspec/pubspec_validator.dart';
import 'package:analyzer/src/pubspec/pubspec_warning_code.dart';
import 'package:analyzer/src/util/yaml.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

/// Validate the value of the optional `flutter` field.
void flutterValidator(PubspecValidationContext ctx) {
  /// Return `true` if an asset (file) exists at the given absolute, normalized
  /// [assetPath] or in a subdirectory of the parent of the file.
  bool assetExistsAtPath(String assetPath) {
    // Check for asset directories.
    Folder assetDirectory = ctx.provider.getFolder(assetPath);
    if (assetDirectory.exists) {
      return true;
    }

    // Else, check for an asset file.
    File assetFile = ctx.provider.getFile(assetPath);
    if (assetFile.exists) {
      return true;
    }
    String fileName = assetFile.shortName;
    Folder assetFolder = assetFile.parent;
    if (!assetFolder.exists) {
      return false;
    }
    for (Resource child in assetFolder.getChildren()) {
      if (child is Folder) {
        File innerFile = child.getChildAssumingFile(fileName);
        if (innerFile.exists) {
          return true;
        }
      }
    }
    return false;
  }

  final contents = ctx.contents;
  if (contents is! YamlMap) return;
  var flutterField = contents.nodes[PubspecField.FLUTTER_FIELD];
  if (flutterField is YamlMap) {
    var assetsField = flutterField.nodes[PubspecField.ASSETS_FIELD];
    if (assetsField is YamlList) {
      path.Context context = ctx.provider.pathContext;
      String packageRoot = context.dirname(ctx.source.fullName);
      for (YamlNode entryValue in assetsField.nodes) {
        if (entryValue is YamlScalar) {
          var entry = entryValue.valueOrThrow;
          if (entry is String) {
            if (entry.startsWith('packages/')) {
              // TODO(brianwilkerson): Add validation of package references.
            } else {
              bool isDirectoryEntry = entry.endsWith("/");
              String normalizedEntry = context.joinAll(path.posix.split(entry));
              String assetPath = context.join(packageRoot, normalizedEntry);
              if (!assetExistsAtPath(assetPath)) {
                ErrorCode errorCode = isDirectoryEntry
                    ? PubspecWarningCode.ASSET_DIRECTORY_DOES_NOT_EXIST
                    : PubspecWarningCode.ASSET_DOES_NOT_EXIST;
                ctx.reportErrorForNode(
                    entryValue, errorCode, [entryValue.valueOrThrow]);
              }
            }
          } else {
            ctx.reportErrorForNode(
                entryValue, PubspecWarningCode.ASSET_NOT_STRING);
          }
        } else {
          ctx.reportErrorForNode(
              entryValue, PubspecWarningCode.ASSET_NOT_STRING);
        }
      }
    } else if (assetsField != null) {
      ctx.reportErrorForNode(
          assetsField, PubspecWarningCode.ASSET_FIELD_NOT_LIST);
    }

    if (flutterField.length > 1) {
      // TODO(brianwilkerson): Should we report an error if `flutter` contains
      // keys other than `assets`?
    }
  } else if (flutterField != null) {
    if (flutterField.value == null) {
      // allow an empty `flutter:` section; explicitly fail on a non-empty,
      // non-map one
    } else {
      ctx.reportErrorForNode(
          flutterField, PubspecWarningCode.FLUTTER_FIELD_NOT_MAP);
    }
  }
}
