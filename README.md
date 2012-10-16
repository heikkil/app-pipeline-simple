app-pipeline-simple
===================

Simple workflow manager written in Perl.


Features
--------

- Control by a command line program
- All intermediate steps are kept
- Run, stop, restart, rerun at will
- Detailed logging
- No custom language
- YAML workflow descriptions
- Branching workflows
- Visualization as graphs


Philosophy
----------

Workflow management in computational (biological) sciences is a hard
problem. This Perl module is based on assumption that UNIX pipe and
redirect system is closest to optimal solution with these
improvements:

**Enforce the storing of all intermediate steps in a file**

> This is for clarity, accountability and to enable arbitrarily big data
> sets. Pipeline can contain independent steps that remove intermediate
> files if so required.

**Naming of each step**

> This is to make it possible to stop, restart, and restart at any
> intermediate step after adjusting pipeline parameters.

**Detailed logging**

> To keep track of all runs of the pipeline.

A pipeline is a collection of steps that are functionally equivalent
to a pipeline. In other words, execution of a pipeline equals to
execution of a each ordered step within the pipeline. From that
derives that the pipeline object model needs only one class that can
recursively represent the whole pipeline as well as individual steps.


Installation
------------

The working version should be installed from [CPAN][metacpan]:

    $ cpanm spipe

or

    $ cpanm App::Pipeline::Simple


Getting started
---------------

Read about runtime and configuration options from [the spipe online
documentation][spipe]:

    $ spipe -h


Development
-----------

Pipeline::Simple source repository is managed with [Dist::Zilla][dzil]
and [hosted on GitHub][development].



[metacpan]: http://metacpan.org/release/App-Pipeline-Simple
[spipe]: http://metacpan.org/module/spipe
[dzil]: http://dzil.org/
[development]: http://github.com/heikkil/app-pipeline-simple
