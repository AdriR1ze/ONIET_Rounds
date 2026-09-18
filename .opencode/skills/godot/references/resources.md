# Resources

Use `Resource` for reusable data/configuration that benefits from being an asset.

Good candidates:

- weapon definitions
- enemy stats
- item definitions
- level configuration
- ability data
- balancing/configuration data

Keep runtime state separate from shared Resource data when mutation could
accidentally affect multiple instances.

Do not create a Resource for a simple local variable or one-off state.

Prefer Resources when the data should be edited, reused, serialized or shared.
