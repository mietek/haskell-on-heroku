[Haskell on Heroku](https://haskellonheroku.com/)
==================================================

Haskell on Heroku is a [Heroku](https://heroku.com/) buildpack for deploying Haskell apps.

The buildpack uses [Halcyon](https://halcyon.sh/) to install apps and development tools, including [GHC](https://downloads.haskell.org/~ghc/latest/docs/html/users_guide/) and [Cabal](https://www.haskell.org/cabal/users-guide/).

See the [Haskell on Heroku website](https://haskellonheroku.com/) for more information.


Usage
-----

Create a new Heroku app with the `heroku create` command, using the `-b` option to specify the buildpack:

```
$ heroku create -b https://github.com/mietek/haskell-on-heroku
```


### Documentation

- Start with the [Haskell on Heroku tutorial](https://haskellonheroku.com/tutorial/) to learn how to develop a simple Haskell web app and deploy it to Heroku.

- See the [Haskell on Heroku reference](https://haskellonheroku.com/reference/) for a complete list of available commands and optinos.


#### Internals

Haskell on Heroku is written in [GNU _bash_](https://gnu.org/software/bash/), using the [_bashmenot_](https://bashmenot.mietek.io/) library.

- Read the [Haskell on Heroku source code](https://github.com/mietek/haskell-on-heroku) to understand how it works.


About
-----

Made by [Miëtek Bak](https://mietek.io/).  Published under the [MIT X11 license](https://halcyon.sh/license/).  Not affiliated with Heroku.
