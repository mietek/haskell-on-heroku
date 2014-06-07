----


Haskell on Heroku
=================

[Haskell on Heroku][] is a fast buildpack for deploying [Haskell][] web apps on [Heroku][].


Features
--------

*   **Fast:**  Deploy a new app in 45 seconds, on average.  Push a change in 30 seconds, on average.

*   **Efficient:**  No unnecessary recompiling or relinking.  Minimal caching.  Minimal slugs, at 3MB for an average “Hello, world!”

*   **Flexible:**  Use any Haskell web framework.  Use any GHC version.  Use GHCi as usual.


Quick start
-----------

With [Heroku Toolbelt][] and [Git][] installed, try:

1.  Clone an example [Snap][] app:

        git clone https://github.com/mietek/haskell-on-heroku-examples.git
        mv haskell-on-heroku-examples/hello-snap .
        cd hello-snap

2.  Commit the app to a new Git repo:

        git init
        git add .
        git commit -m "Initial commit"

3.  Create a new Heroku app:

        heroku create -b https://github.com/mietek/haskell-on-heroku.git

4.  Deploy the app on Heroku:

        time git push heroku master
        heroku ps:scale web=1
        heroku open

To write the example app from scratch, check the [Hello Snap][] documentation.

For a more advanced example, showing how to use [snaplets][] and [Heroku Postgres][], try [Hello Snap with Postgres][].


Questions
---------

###  Can I use another web framework?

Yes.  All Haskell web frameworks should work with Haskell on Heroku.  Prepared packages are available for the [Happstack][], [Scotty][], [Snap][], [Spock][], and [Yesod][] Haskell web frameworks.  For examples, try:

*   [Hello Happstack Lite][]
*   [Hello Scotty][]
*   [Hello Snap][]
*   [Hello Snap with Postgres][]
*   [Hello Spock][]
*   [Hello Yesod][]
*   [Hello Yesod Platform][]


###  Does this have the latest GHC?

Yes.  Prepared packages are available for [GHC 7.8.2][].  Most other GHC versions should also work with Haskell on Heroku.


###  Can I use GHCi with this?

Yes.  Once an app is deployed, use a [one-off dyno][] to run GHCi within the app sandbox:

    heroku run bash
    restore
    cabal repl


###  What do I need to know about Heroku?

Apps deployed on Heroku must listen for incoming connections on the [provided `PORT`][].  All [log output][] is expected on standard output or standard error.  Apps using [Heroku Postgres][] should connect to the database using the [`DATABASE_URL` provided][] by Heroku.  Finally, apps should be aware of the implications of [HTTP routing][] on Heroku.

For more information about deploying web apps on Heroku, browse the [Heroku Dev Center][], or read the [Heroku Hacker’s Guide][].

To learn about modern web app architecture, read the [Twelve-Factor App][].


###  Can I skip the `Procfile`?

Yes.  Haskell on Heroku will generate a default [`Procfile`][], taking the executable name from the Cabal package description file.


###  Can I include a `.profile.d` script?

Yes.  Haskell on Heroku will also generate its own [`.profile.d` script][], named `haskell-on-heroku.sh`.


###  I don’t trust this.  Where do these packages come from?

Trusting [any precompiled software][] requires careful thought.  Haskell on Heroku packages are prepared by [Least Fixed][], hosted on Amazon S3, and updated daily, as a service for the Haskell community.

You can also prepare and host your own Haskell on Heroku packages, retaining complete control over your code.


###  How exactly do I prepare my own packages?

To prepare your own packages on Heroku, create a new Heroku app, configure your Amazon S3 details, and attempt to deploy the app.  Without prepared packages in place, Haskell on Heroku will deploy an app-less slug, containing only itself.  Next, use a [one-off PX dyno][] to prepare the packages:

    heroku run --size=PX prepare

Finally, deploy the app again, by either commiting a change and pushing, or rebuilding:

    heroku plugins:install https://github.com/heroku/heroku-repo.git
    heroku repo:rebuild

It is also possible to prepare packages off Heroku, using any 64-bit machine running Ubuntu 10.04 LTS.


###  How do I configure this?

To set [configuration variables][], use `heroku config:set`.

Variable                        | Default   | Description
--------------------------------|-----------|------------
`HALCYON_AWS_ACCESS_KEY_ID`     | —         | Use this Amazon S3 key to access private prepared packages
`HALCYON_AWS_SECRET_ACCESS_KEY` | —         | Use this Amazon S3 key to access private prepared packages
`HALCYON_S3_BUCKET`             | —         | Use this Amazon S3 bucket to keep prepared packages
`HALCYON_S3_ACL`                | `private` | Use this Amazon S3 ACL to control access to prepared packages
`HALCYON_PURGE_CACHE`           | `0`       | When `1`, delete all prepared packages from cache before compiling
`HALCYON_SILENT`                | `0`       | When `1`, hide all expected external command output
`HALCYON_FORCE_GHC_VERSION`     | —         | Use this GHC version instead of inferring it
`HALCYON_NO_CUT_GHC`            | `0`       | When `1`, use GHC prepared without deleting extraneous files
`HALCYON_FORCE_CABAL_VERSION`   | —         | Use this Cabal version instead of inferring the version
`HALCYON_FORCE_CABAL_UPDATE`    | `0`       | When `1`, update Cabal instead of using a recently updated prepared package


###  I still have questions.  Can I ask you a question?

Yes.  [Least Fixed][] offers commercial support for Haskell on Heroku.  Say hello@leastfixed.com


Thanks
------

Thanks to [Joe Nelson][] and [Neuman Vong][] for their work on Haskell buildpacks, and to [Tweag I/O][] and [Purely Agile][] for advice and assistance.


Meta
----

Written by [Miëtek Bak][].  Say hello@mietek.io

Available under the MIT License.


----

[Haskell on Heroku]:            https://github.com/mietek/haskell-on-heroku
[Haskell]:                      http://www.haskell.org
[Heroku]:                       https://www.heroku.com

[Heroku Toolbelt]:              https://toolbelt.herokuapp.com
[Git]:                          http://git-scm.com
[Snap]:                         http://snapframework.com
[Hello Snap]:                   https://github.com/mietek/haskell-on-heroku-examples/tree/master/hello-snap
[snaplets]:                     http://snapframework.com/snaplets
[Heroku Postgres]:              https://www.heroku.com/postgres
[Hello Snap with Postgres]:     https://github.com/mietek/haskell-on-heroku-examples/tree/master/hello-snap-with-postgres

[GHC]:                          http://www.haskell.org/ghc
[Cabal]:                        http://www.haskell.org/cabal
[Hackage]:                      http://hackage.haskell.org/packages
[Happstack]:                    http://happstack.com
[Scotty]:                       https://github.com/scotty-web/scotty
[Spock]:                        https://github.com/agrafix/Spock
[Yesod]:                        http://www.yesodweb.com
[Hello Happstack Lite]:         https://github.com/mietek/haskell-on-heroku-examples/tree/master/hello-happstack-lite
[Hello Scotty]:                 https://github.com/mietek/haskell-on-heroku-examples/tree/master/hello-scotty
[Hello Spock]:                  https://github.com/mietek/haskell-on-heroku-examples/tree/master/hello-spock
[Hello Yesod]:                  https://github.com/mietek/haskell-on-heroku-examples/tree/master/hello-yesod
[Hello Yesod Platform]:         https://github.com/mietek/haskell-on-heroku-examples/tree/master/hello-yesod-platform
[GHC 7.8.2]:                    http://www.haskell.org/ghc/download_ghc_7_8_2
[one-off dyno]:                 https://devcenter.heroku.com/articles/one-off-dynos
[provided `PORT`]:              https://devcenter.heroku.com/articles/runtime-principles#web-servers
[log output]:                   https://devcenter.heroku.com/articles/logging#writing-to-your-log
[`DATABASE_URL` provided]:      https://devcenter.heroku.com/articles/heroku-postgresql#establish-primary-db
[HTTP routing]:                 https://devcenter.heroku.com/articles/http-routing#heroku-headers
[Heroku Dev Center]:            https://devcenter.heroku.com
[Heroku Hacker’s Guide]:        http://www.theherokuhackersguide.com
[Twelve-Factor App]:            http://12factor.net
[`Procfile`]:                   https://devcenter.heroku.com/articles/procfile
[`.profile.d` script]:          https://devcenter.heroku.com/articles/profiled
[any precompiled software]:     http://cm.bell-labs.com/who/ken/trust.html
[one-off PX dyno]:              https://devcenter.heroku.com/articles/dyno-size#setting-dyno-size-one-off-dynos
[configuration variables]:      https://devcenter.heroku.com/articles/config-vars

[Joe Nelson]:                   http://begriffs.com
[Neuman Vong]:                  https://github.com/luciferous
[Tweag I/O]:                    http://www.tweag.io
[Purely Agile]:                 http://purelyagile.com

[Least Fixed]:                  http://leastfixed.com
[Miëtek Bak]:                   http://mietek.io
