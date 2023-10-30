# Contribution Guidelines

## Table of Contents

- [Contribution Guidelines](#contribution-guidelines)
  - [Introduction](#introduction)
  - [Branches](#branches)
  - [Getting ready](#getting-ready)
  - [Code guidelines](#code-guidelines)
  - [Development](#development)
  - [Issues](#issues)
  - [Pull Requests](#pull-requests)
  - [Testing](#testing)
  - [Versioning](#versioning)

## Introduction
This document explains how to contribute to MegaMerge.

Please make sure that you read the [MegaMerge guides](https://confluence.auto.continental.cloud/x/DKCUG) on Confluence.

To get information about setting up your environment you can refere to: [Getting ready](#getting-ready)


## Branches
The project has a `master` branch as the main line.
Overview on main branches used for extension of MegaMerge :
- `testing`
    - testing branch wihtout branch protection
- `staging`
    - Integration branch, used for testing
	- All sourcecode changes shall be merged on this branch first in order to find errors
- `master`
    - Production branch, protected
- New branches (for features and bugfixes) shall be primarily created from `master`  or `staging` branch (depending where the bug is reproduced)
    - Name of the branch for a feature shall be: `feature/<name-of-feature-or-ticket-number>`
	- Name of the branch for a bugfix shall be: `bugfix/<name-of-feature-or-ticket-number>`

## Getting ready
- RubyMine is a good IDE for Ruby and Ruby on Rails
- Another possibility for coding in Ruby is VS Code
- For local tests use XDE, Docker or VDI if applicable
- Follow this [MM setup guide for development](https://confluence.auto.continental.cloud/x/SZKcG)
- You now should have a XDE or other machine with the MegaMerge repo, a own installed GitHub-App and a credentialsfile combined with this
- You should now be able to run MegaMerge local on your environment
- Test it on a own set of meta-repository and sub-repositories

-> Submit a issue for all your changes and ideas, assuming one does not already exist (see [Issues](#issues))

## Code guidelines

- We use Ruby Version 2.7.5 at the moment!
- Respect Ruby Style [Rubocop styleguide](https://github.com/rubocop/ruby-style-guide)
- Respect the MVC pattern. Avoid logic in views.
- Author shall be set to the creator of the file
- Respect Apache 2.0
  - Keep the `LICENSE` file (`COPYING` in this case for MegaMerge tool)
  - In changed original source files mention in the header: the date, what has been changed and by whom
  - Each new file shall have the copyright notice, see http://www.apache.org/licenses/LICENSE-2.0#apply
- All changes shall be tested locally

## Development
- Each new or changed function shall have an Issue in the GitHub Board to reference on and it also shall be discussed before (see [Issues](#issues))
- Create a feature/bugfix branch from the latest commit of master or staging
- Create commits (using a suggestive commit message) with the proposed changes
- Be sure your sourcecode is commented sufficiently 
- Test the changes ([Testing](#testing))
- Push the branch to GitHub
	(- Codeowners can manually merge their branchach to staging. They need no review on staging but then later on master) 
- All others open a Pull Request to merge their branch on staging
- Link the GitHub issue (if applicable) to the Pull Request
- Await a codeowner to merge the Pull Request on staging
- After tests were positive on staging the feature/bugfix branch can be merged to master
- Create a Pull Request to fast forward the changes from staging to master
- All changes must pass a Pull Request review! - Even codeowners changes need to be reviewed
- A codeowner will merge the reviewed Pull Request to master
- Finally changes have to be presented to the product owner

## Issues
- GitHub Issues shall be used for features, bugs and questions
- Labels for issues:
    - `bug`
    - `feature`

- Use a clear and descriptive title for the problem/feature
- Describe the exact steps which reproduce the problem (or describe explicitly the new feature)
- Provide access for the team to your GitHub Organisation in order to check problems

## Pull requests
- Reviews will be done through pull requests by project owners
- In pull request the issue shall be referenced (if applicable) => GitHub will link them
- Please ensure that:
    - Sourcecode is commented
    - Sourcecode is clean and fullfills Ruby coding rules
    - Local tests worked as exspected ([Testing](#testing))
	- Your change is not just beautifying but has functional purpose
	- Document changes in the `CHANGELOG.md` file
	- Commit message contains the GitHub issue => the Pull Request is referenced into the Issue automatically
- After you submit your pull request, verify that all status checks are passing

## Testing
TBD - Team has to define testcases or automatic tests

For now the "all day" usecases shall be checked before creating a Pullrequest.
For example:
- Creating MegaMerge Pullrequests
- Save and Update
- MMPR is created correct
- Finalmerge
- Commit-Ids correct
- All included files and repos shall be checked if merge was done correct
- The behaviour of webhooks shall be tested locally if applicable.

Test first locally then on staging.
The staging shall be used to test the implemention on a server before creating a Pull Request to the master.

## Versioning
MegaMerge uses the versioning format: Major.Minor.Patch

Updated by codeowners:
- Bigger changes that are incompatible with previous versions are `Major`.
- Smaller ones `Minor` are backwards compatible with older versions
Updated automatically:
- `Patch` meaning the correction of bugs are backwards compatible, too 
