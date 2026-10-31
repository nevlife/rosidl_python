# Python message arrays

Regenerate message packages after updating this generator. Existing generated
packages continue to work; their existing conversion capsules keep the same
signatures. C message structures and wire formats are unchanged.

## Assigning arrays

Numeric sequence setters accept native-endian, one-dimensional NumPy arrays with
the exact ROS dtype without visiting each element. With field checking enabled
they also check the bounded-sequence length. Contiguous inputs copy once into
`array.array`; strided/reversed inputs first become contiguous. NumPy arrays of
another dtype or byte order go through `tolist()` and then the same conversion and
checks as a list, so a float64 array assigned to `float32[]` stores the converted
values, as stock Jazzy does. Arrays with more than one dimension raise
`TypeError`. NumPy boolean sequences use `tolist()` and keep their existing list
representation. Correctly typed `array.array` inputs and `bytes`/`bytearray` for
`uint8[]` keep their fast paths. Ordinary Python sequences retain their existing
element/range checks when field checking is enabled.

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
