// generated from rosidl_generator_py/resource/_idl_pkg_bases.c.em
// generated code does not contain a copyright notice
#include <Python.h>
#include <structmember.h>
#include <stddef.h>
@{
from rosidl_parser.definition import Action
from rosidl_parser.definition import Message
from rosidl_parser.definition import Service
messages = list(content.get_elements_of_type(Message))
for service in content.get_elements_of_type(Service):
    messages.extend([service.request_message, service.response_message, service.event_message])
for action in content.get_elements_of_type(Action):
    messages.extend([
        action.goal, action.result, action.feedback,
        action.send_goal_service.request_message, action.send_goal_service.response_message,
        action.send_goal_service.event_message, action.get_result_service.request_message,
        action.get_result_service.response_message, action.get_result_service.event_message,
        action.feedback_message])
}@
@[for message in messages]@
@{TEMPLATE('_msg_native.h.em', message=message)}@
@{
from rosidl_parser.definition import EMPTY_STRUCTURE_REQUIRED_MEMBER_NAME
native_name = '__'.join(message.structure.namespaced_type.namespaced_name()) + '__PyBase'
native_fields = ['_check_fields']
for m in message.structure.members:
    if m.name != EMPTY_STRUCTURE_REQUIRED_MEMBER_NAME:
        native_fields.append('_' + m.name)
native_fields.sort()
base_name = '__'.join(message.structure.namespaced_type.namespaced_name()[1:]) + 'Base'
}@
static int @(native_name)__traverse(@(native_name) * self, visitproc visit, void * arg)
{
@[for field in native_fields]@
  Py_VISIT(self->@(field));
@[end for]@
  return 0;
}

static int @(native_name)__clear(@(native_name) * self)
{
@[for field in native_fields]@
  Py_CLEAR(self->@(field));
@[end for]@
  return 0;
}

static void @(native_name)__dealloc(@(native_name) * self)
{
  PyObject_GC_UnTrack(self);
  @(native_name)__clear(self);
  PyTypeObject * type = Py_TYPE(self);
  type->tp_free((PyObject *)self);
  Py_DECREF(type);
}

static PyMemberDef @(native_name)__members[] = {
@[for field in native_fields]@
  {"@(field)", T_OBJECT_EX, offsetof(@(native_name), @(field)), 0, NULL},
@[end for]@
  {NULL, 0, 0, 0, NULL}
};

static PyType_Slot @(native_name)__slots[] = {
  {Py_tp_new, PyType_GenericNew},
  {Py_tp_traverse, @(native_name)__traverse},
  {Py_tp_clear, @(native_name)__clear},
  {Py_tp_dealloc, @(native_name)__dealloc},
  {Py_tp_members, @(native_name)__members},
  {0, NULL}
};

static PyType_Spec @(native_name)__spec = {
  "@(package_name)._@(package_name)_bases.@(base_name)",
  sizeof(@(native_name)), 0,
  Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
  @(native_name)__slots
};
@[end for]@

static struct PyModuleDef bases_module = {
  PyModuleDef_HEAD_INIT,
  "_@(package_name)_bases",
  NULL, -1, NULL, NULL, NULL, NULL, NULL
};

PyMODINIT_FUNC
PyInit__@(package_name)_bases(void)
{
  PyObject * module = PyModule_Create(&bases_module);
  if (module == NULL) {
    return NULL;
  }
@[for message in messages]@
@{
native_name = '__'.join(message.structure.namespaced_type.namespaced_name()) + '__PyBase'
base_name = '__'.join(message.structure.namespaced_type.namespaced_name()[1:]) + 'Base'
}@
  {
    PyObject * type = PyType_FromSpec(&@(native_name)__spec);
    if (type == NULL || PyModule_AddObject(module, "@(base_name)", type) < 0) {
      Py_XDECREF(type);
      Py_DECREF(module);
      return NULL;
    }
  }
@[end for]@
  return module;
}
