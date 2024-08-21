# Changelog
All notable changes in MegaMerge will be documented in this file.

## [3.13.0] - 08.14.2024
### Added
 - [Feature]: Support multiple manifest files from one meta. The user can select one or more top level (not already included in other manifest files)
			  manifest files. All provided Repositories are scanned for possible PRs to be opned. If there is a Repository present in more than one of 
			  the manifest files, its hash will be udpated in all of them.
        
### Changed

### Removed

## [3.12.1] - 05.15.2024
### Added
 - [Feature]: Fix text for OpenSource

## [3.12.0] - 05.06.2024
### Added
 - [Feature]: Check PR summary as API call (check if: dismiss_stale_pr (disabled), restricted_push (disabled) and access to all included repos)

### Changed

### Removed

## [3.11.0] - 03.14.2024
### Added
 - [Feature]: Subrepository template dropdown sets template default if there is only one template present

### Changed

### Removed

## [3.10.2] - 02.12.2024
### Added
 - [Feature]: Show error messsage if merge method "rebase" is not possible on one of the repositories
 - [Feature]: Show "rebaseable" state of each repo in GUI on xml file and as return value for API calls

### Changed

### Removed

## [3.10.1] - 01.25.2024
### Added
 - [Feature]: Return 'mergeable_state' at retrieve pull request api call

### Changed

### Removed

## [3.10.0] - 01.16.2024
### Added
 - [Feature]: Add dropdown to support all three merge methods SQUASH, REBASE and MERGE

### Changed
 - [Feature]: Remove merge method SQUASH toggle button 

### Removed

## [3.9.7] - 10.17.2023
### Added
 - [Feature]: Add NOTICE.txt for update of MM Open Source repository

### Changed

### Removed
 - [Feature]: Remove content_security_policy.rb for update of MM Open Source repository

## [3.9.6] - 10.16.2023
### Added
 - [FIX]: Fix dublicate subs error in case of invalid project

### Changed

### Removed

## [3.9.5] - 10.12.2023
### Added
 - [FIX]: Update revision of all ocurences of a subrepo in manifest file
 - [FIX]: PR Creation not allowed if I have not access to all subrepos

### Changed

### Removed

## [3.9.4] - 09.18.2023
### Added
 - [FIX]: pr_templates are not present error

### Changed

### Removed

## [3.9.3] - 09.06.2023
### Added
 - [GUI]: `Description` Draft state info in generated MM PR description
 - [FIX]: pr_template is nil error

### Changed

### Removed

## [3.9.2] - 08.08.2023
### Added
 - [Test]: Add a playground instance for live testing

### Changed

### Removed

## [3.9.1] - 07.26.2023
### Added
 - [Fix]: Removed misleading error message about not found manifest file after successful merge
 - [FIX]: Updated security policy according to ccif
 - [GUI]: Improved generated PR description 

### Changed

### Removed

## [3.9] - 06.29.2023
### Added
 - [Feature]: Enabled include feature
 - [GUI]: Added Announcement banner for the include feature to the main Mega Merge page
 - [GUI]: `Find All` button - adds all sub PRs with the same source branch as the meta PR to the meta PR
 - [GUI]: Meta PR template select menu - able to choose between multiple templates for meta PR during MM PR creation
 - [GUI]: Sub PR template select menu - able to choose between multiple templates for sub PR during MM PR creation
 - [GUI]: `Description` button for sub PRs - shows sub PR template
 - [GUI]: `Branch` column on the meta repository page - shows meta PR source and target branches
 - [GUI]: `Source branch` column on the MM PR page - shows the source branch of meta and sub PRs, also acts as a link to the GitHub source branch page
 - [GUI]: Source branch select menu for sub PRs - able to select a different source branch for sub PRs
 - [GUI]: `Target branch` column on the MM PR page - shows the target branch of meta and sub PRs, also acts as a link to the GitHub target branch page
 - [GUI]: `Squash` button next to the target branch - enables/disables squash and merge(enabled by default)
 - [Fix]: Ignored white spaces for MM PR titles
 - [Fix]: Merge is no longer blocked to branches without protection rules even if changes are requested in the PR
 - [Fix]: 502 Bad Gateway GitHub error fixed by executing GQL in batches
 - [Fix]: In draft PR state, use source branch head hash instead of the pseudo-merge hash
 - [API]: Check remaining rate limit: `/api/v1/:organization/:repository/rate_limit`
 - [API]: Make PR ready for review: `/api/v1/:organization/:repository/pull/:number/ready_for_review`
 - [Test]: Enabled Auto-Merging the Test PR in auto test case

### Changed
 - [GUI]: Renamed `Sub Pull Request` button to `Add` button
 - [GUI]: Changed tooltip next to the `Sub Pull Requests` heading to accomodate new buttons

### Removed

## [3.8.323] - 09.29.2022
### Added

### Changed
 - Disabled include again

### Removed

## [3.8.318] - 09.20.2022
### Added

### Changed
 - XML files that are in "external_manifests" folder will be always ignored by MegaMerge

### Removed

## [3.8.317] - 09.19.2022
### Added
- activated include feature
- symlink will be respected
- draft label is now shown on PR overview page

### Changed
- "default remote" in XML file will be respected!
- draft button no longer clickable during update process
- source branch name is no longer cut off

### Removed

## [3.8.308] - 07.21.2022
### Added
- Added API parameter: reviews_done
	can be true/ false
	Status is seperate for each repository in the MMPR

### Changed

### Removed

## [3.8.306] - 07.19.2022
### Added

### Changed
- Adapted contributing file
- Changed logger
- Branch protection

### Removed
-Removed Subrepo Actions

## [3.8.305] - 06.23.2022
### Added

### Changed
- Changed mergable state. Added third state that means GitHub is still calculating.

### Removed

## [3.8.299] - 06.01.2022
### Added
- introduced CONTRIBUTING.md, CHANGELOG.md, CODEOWNERS.md

### Changed
- branch protection

### Removed












