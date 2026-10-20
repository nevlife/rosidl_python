# Python message arrays

Regenerate message packages after updating this generator. Existing generated
packages continue to work; their existing conversion capsules keep the same
signatures. C message structures and wire formats are unchanged.

## Assigning arrays

Numeric sequence setters accept native-endian, one-dimensional NumPy arrays with
the exact ROS dtype. They validate dtype, dimensions, and bounded-sequence length
without visiting each element. Contiguous inputs copy once into `array.array`;
strided/reversed inputs first become contiguous. NumPy boolean sequences use
`tolist()` and keep their existing list representation. Correctly typed
`array.array` inputs and `bytes`/`bytearray` for `uint8[]` keep their fast paths.
Ordinary Python sequences retain their existing element/range checks when field
checking is enabled. Invalid typed NumPy buffers are rejected even when ordinary
field checking is disabled.

`sequence<octet>` (`byte[]`, including bounded sequences) now maps to Python
`bytes`, with `b''` as its empty default. This is an intentional Python API change:
assign bytes instead of lists of one-byte bytes objects. Scalar octets and fixed
arrays of octets retain their previous representation. `uint8[]`, as used by
Image and PointCloud2, is a different IDL type and retains its normal default
`array.array` representation.

## Opt-in received views

Set `RCLPY_MESSAGE_ARRAYS=numpy` before starting a process to make rclpy
subscriptions and `deserialize_message` return read-only NumPy views for numeric
primitive arrays and sequences, including boolean sequences. This setting is
cached at the first received conversion. Generated constructors and normal
setters still use their ordinary containers. Octet sequences remain bytes;
string/message sequences retain their usual containers.

The NumPy C API creates each ndarray directly over the taken buffer, with its
base set to an owning capsule for the entire taken C message.
Nested regenerated messages share that owner. Extracting a field or slicing its
array keeps the C message alive after the wrapper message and subscription are
deleted. The last view releases the owner. No extra slot or field is added to the
message class or the C message. Empty arrays also retain their owner. The arrays
cannot be made writable using `setflags(write=True)`; use `field.copy()` when
mutation is required. Republishing and serialization accept these views.

The ordinary `_CONVERT_TO_PY` capsule always makes an independent Python copy.
An additive `_CONVERT_TO_PY_WITH_OWNER` capsule accepts the C message pointer and
an owning Python object. The ordinary capsule's context advertises the owned
converter for messages that can contain numeric buffers. rclpy checks that context
only when the opt-in is enabled. Scalar-only messages use the ordinary converter
without allocating an owner. For mixed generated packages, dependencies without
the new capsule continue to copy. An old generated root type has no context and
also uses the ordinary converter. The legacy Python view factory remains available
for previously generated packages, but regenerated converters use the NumPy C API.
Services/actions currently keep their existing copying receive paths.

The opt-in removes the C-to-Python payload copy. It does not remove the RMW/CDR
copy into the taken C message or the Python-to-C copy on publish. Keeping a tiny
slice retains the entire C message, so applications should copy small selections
when they otherwise hold a large message for a long time. Direct C API view
construction avoids a Python function call and buffer wrapper for each array.
Extensions built against NumPy 1.26 or NumPy 2 headers run with both NumPy 1.26
and NumPy 2 runtimes. With NumPy 1.x headers the converter loads the NumPy C API
table itself, because the stock `_import_array()` rejects the NumPy 2 ABI. The
table slots it uses (`PyArray_New`, `PyArray_SetBaseObject`, `PyArray_Type`) and
the `PyArrayObject` fields it reads are the same in both ABIs.

Consumers that mutate incoming buffers need an explicit copy. In particular,
`sensor_msgs_py.point_cloud2.read_points` in this checkout swaps a foreign-endian
cloud in place. Copy its `data` field before using that operation with this opt-in.
Native-endian point-cloud reads can use the retained buffer directly.

## Native message bases

The native-base port follows rosidl_python PR #193, including its October 2026
rebase, while retaining this branch's conversion caches and single-copy array
construction. A generated private C-extension base holds Python object references;
converters read and fill them directly. Python scalar semantics, slot metadata,
field reflection, pickling, and the lack of an instance dictionary are preserved.
The native base implements GC traverse/clear and is a heap type, including proper
type-reference release. Fields use the same sorted pointer-slot layout and object
size as the earlier Python slots. Scalar unboxing from the upstream prototype is
not included because preserving that layout and Python field semantics takes
precedence. Existing public C conversion symbols remain available.
