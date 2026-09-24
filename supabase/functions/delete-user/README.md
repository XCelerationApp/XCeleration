# delete-user

Deletes the caller's own account. Invoked by `AuthService.deleteCurrentUserAccount`
from the Delete Account button in settings.

The function is deployed with `verify_jwt = false` because it does the check
itself: it reads the caller's token from the `Authorization` header, resolves
it to a user, and deletes **that** user and no other. The service role key
never leaves the function.

Deployed to the project as `delete-user`. This copy is the source of truth —
it was live for six months before it was committed anywhere.
