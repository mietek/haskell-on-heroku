[Haskell on Heroku](https://haskellonheroku.com/)
==================================================

Haskell on Heroku is a [Heroku](https://heroku.com/) buildpack for deploying Haskell apps.

The buildpack uses [Halcyon](https://halcyon.sh/) to install apps and development tools, including [GHC](https://downloads.haskell.org/~ghc/latest/docs/html/users_guide/) and [Cabal](https://www.haskell.org/cabal/users-guide/).

**Follow the [Haskell on Heroku tutorial](https://haskellonheroku.com/tutorial/) to get started.**


Usage
-----

Haskell on Heroku, like other [Heroku buildpacks](https://devcenter.heroku.com/articles/buildpacks), can be used when creating a new Heroku app:

```
$ heroku create -b https://github.com/mietek/haskell-on-heroku
```

Push the code to Heroku in order to deploy your app:

```
$ git push heroku master
```


### Documentation

- **Start with the [Haskell on Heroku tutorial](https://haskellonheroku.com/tutorial/) to learn how to develop a simple Haskell web app and deploy it to Heroku.**

- Read the [Halcyon tutorial](https://halcyon.sh/tutorial/) to learn more about developing Haskell apps using Halcyon.

- See the [Haskell on Heroku reference](https://haskellonheroku.com/reference/) for a list of buildpack-specific options.

- Look for additional options in the [Halcyon reference](https://halcyon.sh/reference/).


#### Internals

Haskell on Heroku is written in [GNU _bash_](https://gnu.org/software/bash/), using the [_bashmenot_](https://bashmenot.mietek.io/) library.

- Read the [Haskell on Heroku source code](https://github.com/mietek/haskell-on-heroku) to understand how it works.


About
-----

Made by [Miëtek Bak](https://mietek.io/).  Published under the [MIT X11 license](https://halcyon.sh/license/).  Not affiliated with Heroku.
