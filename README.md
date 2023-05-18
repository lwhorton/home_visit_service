# Home Visit Service

## notes

- let's use 'raw' elixir, not phoenix or some other framework-ey solution. we
  want to avoid bloated templates and/or unnecessary cruft
- in an effort to keep our time investment down on this example application,
  we'll make liberal use of `# todo`
- we'll go with a CLI interface because we want leightweight and data-oriented.
  you can always extend a data-driven interface with a GUI, but you can't often
  go the other way. small, powerful interfaces give way to more convenient,
  expressive interfaces over time.
- be a good CLI citizen, return 0 / 1
- writing really good error messages for CLIs is _hard_ and very time consuming.
  we're not going to put in too much time here, just the basics will suffice.
- don't reinvent the wheel; use an args parsing solution. optimus is a thing,
  along with a few other libs, but since 1.12 elixir has a built-in
  OptionParser. lets do the simplest thing without introducing another
  dependency.
- don't make our users spin up a pg/msql database, which would often involve
  docker or some other operations lift. lets keep it simple and use a local file
  store via sqllite3, which comes preinstalled on most dev machines, or can be
  installed with `brew` trivially.

## some API surface area exploration

What would a consumer like to be able to do in this "home visit service" domain?
For our purposes, we're going to assume the intended consumer is an already
authenticated admin on the platform, servicing requests on behalf of pals /
members. We can sidestep any sort of authn/authz with this assumption.

```
create-user --name luke --surname horton --email lukewhorton@me.com --role member --role pal
get-user --user-id _
grant-role --user-id _ --role member --role pal
revoke-role --user-id _ --role pal
solicit-visit --member-id _ --duration _ --commencement _ --tasks _
fulfill-visit --visit-solicitation-id _ --pal-id _ --fulfilled _
```

## some lightweight domain modeling

```
users

name ""
surname ""
email ""
roles #{:member, :pal} # normally a set of ->fkey roles.id, but lets go with 'simple' for now
balance_minutes integer
```

```
visit_solicitations

solicitor ->fkey users.id
commencement "2023-01-01 00:00:00Z"
duration_minutes integer
tasks "" # keep it simple, a string will suffice for now
```

```
visit_fulfillments

visit_solicitations_id ->fkey visit_solicitations.id
member_id ->fkey users.id
pal_id ->fkey users.id
fulfilled "2023-01-01 00:00:00Z"
```

Given more time, we should probably...

- further explore to determine if there's an important distinction between a
  member and a pal, or if we can unify these roles under a user. what does that
  mean for changes in roles over time, auditability, etc.?
- introduce a whole host of more comprehensive auditability/instrumentation data
  such as capturing the fee at the time of the fulfillment, recording the
  success/failure of tasks, actual/presumed duration of fulfillment, etc.. i
  don't want to spend too much time here boiling the ocean, though.
- introduce some sort of mutex management around balances. soliciting a visit
  should probably put a hold on available minutes, but those minutes are freed
  after some time, for example.

## general implementation guidance

you will probably need to install `sqllite3`. try homebrew, if on macos.

you shouldn't need elixir or erlang installed, since this is a burrito binary.
see `.tool-versions` for details, though, if something is amiss.

we're not super concerned with the cleanliness of CLI outputs. it takes a while
to get the interface correct, and it's a little painful to integrate into unix*
stream / piping stdin, stderr. we're just going to return elixir structs, mostly.

elixir isn't an optimal tool for a CLI in my opinion, at least not without a lot
of up front effort. it's VM-based and has a slow startup time. a persistence
layer (such as Ecto) generally requires starting up an application with a
supervisor. the built-in, lightweight `escript` feature doesn't support NIF libs
(so Ecto and its backing implementations are out of the question). deploying a
binary that can easily read from the command line is a bit harder than it should
be. building a "running" CLI (keeping the prompt alive) requires yet more work
setting up supervised `IO.gets()` loops. given all these concerns, and a limited
amount of time to work on an example application, interactions with the
home_services_application are simply going to happen through remote process
execution (see below).

the application release is prebuilt. `HomeVisitService.main(argv)` is our
entrypoint, and it expects a standard unix argv list of strings.

```
> ./home_visit_service start
(another shell)
> ./home_visit_service remote

HomeVisitService.main(["--create-user", "--name", "Luke", "--surname", "Horton", "--email", "em@me.com", "--role", "pal"])
HomeVisitService.main(["--get-user", "--user-id", "1"])
HomeVisitService.main(["--grant-balance", "--user-id", "1", "--balance", "120"])
HomeVisitService.main(["--grant-role", "--role", "member", "--user-id", "1"])
HomeVisitService.main(["--revoke-role", "--role", "pal", "--user-id", "1"])
HomeVisitService.main(["--solicit-visit", "--member-id", "1", "--duration", "60", "--commencement", "2023-05-18 12:00:00Z", "--tasks", "take out the trash, play cards"])
HomeVisitService.main(["--fulfill-visit", "--pal-id", "1", "--fulfilled", "2023-05-18 12:00:00Z", "--visit-solicitation-id", "1"])
```

run the tests via the standard `mix test` flow.
