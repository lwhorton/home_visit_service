# getting started

# initial notes

- let's use 'raw' elixir, not phoenix or some other framework-ey solution
  because we're not looking to spend forever on an example application
- we'll go with CLI interface because we want leightweight and data-oriented.
  you can always extend a data-driven interface with a GUI, but you can't often
  go the other way. small, powerful interfaces give way to more convenient,
  expressive interfaces over time.
- be a good CLI citizen, return 0 / 1 and data
- don't reinvent the wheel; use an args parsing solution. optimus is a thing,
  but since 1.12 elixir has a built-in OptionParser.
- don't make our users spin up a database, which would often involve docker or
  some other operations lift. lets keep it simple and use a local file store as
  a source of truth.


 - user will still need erlang on their system unless we introduce bakeware,
   burrito


# some lightweight domain exploration

What would a consumer like to be able to do in this "home visit service" domain?
For our purposes, we're going to assume the intended consumer is an admin on the
platform servicing requests on behalf of pals / members.

```
create-user --first-name luke --last-name horton --email lukewhorton@me.com --role member --role pal
grant-role --user-id _ --role member --role pal
revoke-role --user-id _ --role pal
solicit-visit --user-id _ --duration _ --commencement _ --tasks ""
fulfill-visit --visit-solicitation-id _ --member-id _
```

# some lightweight domain modeling

```
users

first_name ""
last_name ""
email ""
account_id ->fkey accounts.id
roles #{:member, :pal} # normally a set of ->fkey roles.id
balance_minutes integer
```

```
visit_solicitations

solicitor ->fkey users.account_id
commencement "2023-01-01 00:00:00Z"
duration_minutes integer
tasks ""
```

```
visit_fulfillments

visit_solicitations_id ->fkey visit_solicitations.id
member_id ->fkey users.id
pal_id ->fkey users.id
fulfilled "2023-01-01 00:00:00Z"
```

- requires further exploration to determine if there's really a distinction
  between a member and a pal, or if we can unify these roles under a user. what
  does that mean for changes in roles over time, auditability, etc.?
- this requires a whole host of more comprehensive auditability/instrumentation
  data such as capturing the fee at the time of the fulfillment, recording the
  success/failure of tasks, actual duration of fulfillment, etc.. i don't want
  to spend too much time here boiling the ocean, though.
