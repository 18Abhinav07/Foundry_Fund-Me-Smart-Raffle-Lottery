## ADVANCED FOUNDRY COURSE _PROJECTS_ NOTES

```sh
require(<condition>, "error");

```

is less gas efficient than using custom reverts and errors.

```sh
    require(<condition>, <custom-revert-error>);
```

is much more efficient but is on newer sol verisons.

```sh
    if(<condition>){
        revert <error>;
    }
```

is best in terms of efficiency.
