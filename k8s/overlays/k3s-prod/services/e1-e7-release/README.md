# E1-E7 release lock

This is an evidence record only. Do not apply or roll out without parent review.

Prerequisites: managed-config references, OpenBao readiness, signed-health, tenant binding, and JWT audience/issuer validation. No secret values are recorded here.

Rollback uses the deployment's captured prior immutable image reference; never delete rollback tags.
