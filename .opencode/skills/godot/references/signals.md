# Signals

Use signals to communicate events without requiring the sender to know every
listener.

Good examples:

- health changed
- enemy died
- button pressed
- wave completed
- player entered a state

Prefer direct method calls when there is a clear owner and only one tightly
coupled receiver.

Avoid:

- signals for ordinary synchronous operations
- huge chains of signals that make execution difficult to follow
- global event buses for local events
- signals that hide critical control flow unnecessarily

Keep connections explicit and easy to trace.
