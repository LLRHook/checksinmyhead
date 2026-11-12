package safehttp

import (
	"reflect"
	"strings"
	"unicode/utf8"
)

// validJSONText visits a decoded request shape once, including nested DTOs and
// their pointer/slice fields. PostgreSQL UTF-8 text (including JSONB strings)
// cannot store NUL or invalid UTF-8. encoding/json already replaces malformed
// Unicode, so the wire check adds only NUL rejection; other controls stay legal.
// Inspecting the DTO, rather than the raw body, preserves ignored-field behavior.
func validJSONText(v reflect.Value) bool {
	switch v.Kind() {
	case reflect.String:
		s := v.String()
		return !strings.ContainsRune(s, 0) && utf8.ValidString(s)
	case reflect.Pointer, reflect.Interface:
		return v.IsNil() || validJSONText(v.Elem())
	case reflect.Struct:
		for i := 0; i < v.NumField(); i++ {
			if !validJSONText(v.Field(i)) {
				return false
			}
		}
	case reflect.Slice, reflect.Array:
		for i := 0; i < v.Len(); i++ {
			if !validJSONText(v.Index(i)) {
				return false
			}
		}
	case reflect.Map:
		for it := v.MapRange(); it.Next(); {
			if !validJSONText(it.Key()) || !validJSONText(it.Value()) {
				return false
			}
		}
	}
	return true
}
