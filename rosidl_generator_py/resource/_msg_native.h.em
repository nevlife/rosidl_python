@{
from rosidl_parser.definition import EMPTY_STRUCTURE_REQUIRED_MEMBER_NAME
native_name = '__'.join(message.structure.namespaced_type.namespaced_name()) + '__PyBase'
native_fields = ['_check_fields']
for m in message.structure.members:
    if m.name != EMPTY_STRUCTURE_REQUIRED_MEMBER_NAME:
        native_fields.append('_' + m.name)
native_fields.sort()
}@
typedef struct
{
  PyObject_HEAD
@[for field in native_fields]@
  PyObject * @(field);
@[end for]@
} @(native_name);
