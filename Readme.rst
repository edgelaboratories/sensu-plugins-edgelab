========================
Sensu plugins repository
========================

This repository contains custom Sensu plugins developed by Edgelab.


How to use in development
=========================

After cloning the repository, in the repo directory:

* Install dependecies::

    bundle install --path .gems

* You can run one of the ``bin/`` script with the correct dependencies using::

    bundle exec bin/my-script.rb

* Sanity checks with ``rake`` in the bundle context::

    bundle exec rake


How to create a new release
===========================

The repository is hosted on https://bitbucket.org/edgelab/sensu-plugins-edgelab/
and uses Bitbucket Pipeline for continuous integration.

Each commit on master will trigger a new build which run the rake command (with Rubocop code lint)
but no gemfile will be created.

To create a new release, after having changed the version in sensu-plugins-edgelab.gemspec and commit it in master,
create a new git tag::

    # X.X.X is the new version in the gempsec file, tag should be prefix by 'v'
    git tag vX.X.X 
    git push --tags

Pipeline will run a new build and, if successfull, create a new gem and push it to Rubygem.
