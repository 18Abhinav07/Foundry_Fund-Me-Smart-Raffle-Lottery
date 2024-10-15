
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

```sh
forge coverage --report debug > coverage.txt
```

to get a debugged test coverage report in a txt file

### some debugging notes:
--> reached an underflow error on the createSubscription() in the SubscriptionApi.sol while testing on the local blockchain as the blockhash starts at 0 and it did blockhash -1 thus underflow and thus needed to be changed to blockhash + 1.

--> The default sender for the local chain must be the same of which the private key you supply when launching forge script otherwise it will give the "must be subower" error.