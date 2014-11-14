[Haskell on Heroku](https://haskellonheroku.com/)
==================================================

Haskell on Heroku is a system for fast and reliable deployment of Haskell web applications to [Heroku](https://heroku.com/).

**This page describes version 1.0, which is currently undergoing testing.  Check back soon, or follow [@mietek](https://twitter.com/mietek).**


Examples
--------

### “Hello, world!”

- [hello-happstack](https://github.com/mietek/hello-happstack/) ([Live](https://mietek-hello-happstack.herokuapp.com/))
- [hello-mflow](https://github.com/mietek/hello-mflow/) ([Live](https://mietek-hello-mflow.herokuapp.com/))
- [hello-miku](https://github.com/mietek/hello-miku/) ([Live](https://mietek-hello-miku.herokuapp.com/))
- [hello-scotty](https://github.com/mietek/hello-scotty/) ([Live](https://mietek-hello-scotty.herokuapp.com/))
- [hello-simple](https://github.com/mietek/hello-simple/) ([Live](https://mietek-hello-simple.herokuapp.com/))
- [hello-snap](https://github.com/mietek/hello-snap/) ([Live](https://mietek-hello-snap.herokuapp.com/))
- [hello-spock](https://github.com/mietek/hello-spock/) ([Live](https://mietek-hello-spock.herokuapp.com/))
- [hello-wai-warp](https://github.com/mietek/hello-wai-warp/) ([Live](https://mietek-hello-wai-warp.herokuapp.com/))
- [hello-wheb](https://github.com/mietek/hello-wheb/) ([Live](https://mietek-hello-wheb.herokuapp.com/))
- [hello-yesod](https://github.com/mietek/hello-yesod/) ([Live](https://mietek-hello-yesod.herokuapp.com/))


### Real-world

- [gitit](https://github.com/mietek/gitit/) ([Live](https://mietek-gitit.herokuapp.com/))
- [hl](https://github.com/mietek/hl/) ([Live](https://mietek-hl.herokuapp.com/))
- [howistart.org](https://github.com/mietek/howistart.org/) ([Live](https://mietek-howistart.herokuapp.com/))
- [tryhaskell](https://github.com/mietek/tryhaskell/) ([Live](https://mietek-tryhaskell.herokuapp.com/))
- [tryhplay](https://github.com/mietek/tryhplay/) ([Live](https://mietek-tryhplay.herokuapp.com/))
- [tryidris](https://github.com/mietek/tryidris/) ([Live](https://mietek-tryidris.herokuapp.com/))
- [trypurescript](https://github.com/mietek/trypurescript/) ([Live](https://mietek-trypurescript.herokuapp.com/))


Usage
-----

New applications:

```
$ heroku create -b https://github.com/mietek/haskell-on-heroku -s cedar-14
```

Existing applications:

```
$ heroku config:set BUILDPACK_URL=https://github.com/mietek/haskell-on-heroku
```

Haskell on Heroku supports:

- Heroku _cedar_ and [_cedar-14_](https://blog.heroku.com/archives/2014/8/19/cedar-14-public-beta).
- GHC [7.0.4](https://www.haskell.org/ghc/download_ghc_7_0_4), [7.2.2](https://www.haskell.org/ghc/download_ghc_7_2_2), [7.4.2](https://www.haskell.org/ghc/download_ghc_7_4_2), [7.6.1](https://www.haskell.org/ghc/download_ghc_7_6_1), [7.6.3](https://www.haskell.org/ghc/download_ghc_7_6_3), [7.8.2](https://www.haskell.org/ghc/download_ghc_7_8_2), and [7.8.3](https://www.haskell.org/ghc/download_ghc_7_8_3).
- _cabal-install_ [1.20.0.0](https://www.haskell.org/cabal/download.html) and newer.

To learn more, check back soon.


### Internals

Haskell on Heroku is built with [Halcyon](https://halcyon.sh/), a system for deploying Haskell applications, and [_bashmenot_](https://bashmenot.mietek.io/), a library of functions for safer shell scripting in [GNU _bash_](https://gnu.org/software/bash/).

Additional information is available in the [_bashmenot_ programmer’s reference](https://bashmenot.mietek.io/reference/).


### Bugs

Please report any problems with Haskell on Heroku on the [issue tracker](https://github.com/mietek/haskell-on-heroku/issues/).

There is a [separate issue tracker](https://github.com/mietek/haskell-on-heroku-website/issues/) for problems with the documentation.


About
-----

My name is [Miëtek Bak](https://mietek.io/).  I make software, and Haskell on Heroku is one of [my projects](https://mietek.io/projects/).

This work is published under the [MIT X11 license](https://haskellonheroku.com/license/), and supported by my company, [Least Fixed](https://leastfixed.com/).

Like my work?  I am available for consulting on software projects.  Say [hello](https://mietek.io/), or follow [@mietek](https://twitter.com/mietek).


### Acknowledgments

Thanks to [Joe Nelson](http://begriffs.com/), [Brian McKenna](http://brianmckenna.org/), and [Neuman Vong](https://github.com/luciferous/) for initial work on Haskell buildpacks.  Thanks to [CircuitHub](https://circuithub.com/), [Tweag I/O](http://www.tweag.io/), and [Purely Agile](http://purelyagile.com/) for advice and assistance.

[Heroku](https://heroku.com/) is a registered trademark of [Salesforce](https://salesforce.com/).  This project is not affiliated with Heroku.
