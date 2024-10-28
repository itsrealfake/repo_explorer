# README

## What is Core Explorer?
Who watches the watchers?

Core Explorer is an interface designed to audit and review the development process of Bitcoin Core.

As a large-scale open-source project, Bitcoin Core has numerous contributors and a vast codebase, receiving extensive peer review. But how do we know when something falls through the cracks?

The goal of Core Explorer is to systematically review Bitcoin Core contributions to help identify and assess the health of the codebase as an open-source project, while strengthening and facilitating its peer review process.

## Approach
To assess the health of Bitcoin Core's peer review, we've identified a set of behaviors that indicate low levels of peer review. The most obvious of these are self-merges.
- A self-merge occurs when the author of a commit (which may be part of or the entire pull request) is also the maintainer who runs the merge script or merges the code to the master repository.

In other words, a self-merge happens when a developer is the only known person to have reviewed the code being merged into the codebase. If we were to rate that code based on peer review quality, it would receive a score of 1, the lowest possible score.

### Health Metrics
- **Health Metric 1, Self-Merge Ratio:** A high percentage of code merges coming from the same person who committed them can indicate poor project health, as there is little to no third-party peer review. This risk can be reduced by reviews from other contributors, measured in ACKs and other peer review indicators.

- **Health Metric 2, Number of ACKs from Contributors:** This metric tracks the amount of ACKs (approvals) commented in the code discussion.

- **Health Metric 3, Contributor's ACK Rank:** ACKs from each author could be weighted based on the number of commits or merges they’ve made, to prevent trivial ACKs and reduce vulnerability to Sybil attacks.

- **Health Metric 4, Per-Line Index of Self-Merges:** This index rates each line of code merged into Bitcoin, ranking them based on whether they were self-merged.

- **Health Metric 5, Heat Map:** The most concerning self-merge type has zero ACKs in the pull request’s comment section, while the healthiest merge type has a different author and merger and includes numerous ACKs from reputable contributors. This heat map would display lines of code in colors based on the quality of merges and reviews.

![Core Explorer: Healthy Code Merge Workflow in Bitcoin](image.png)

## Responsible Disclosure
- Avoid revealing the developer’s identity until certain that there's a critical issue and the source actor is verified. 
- Clearly describe the process of identifying potential issues in the self-merge test.
- Use randomized anonymous IDs for user data to help improve impartiality and reduce motivated reasoning in creating initial tests.

## Glossary
- **Author:** A person proposing code changes (commits) or merging code.
- **Commit:** Proposed changes to the master code.
- **Maintainer:** Someone with administrative privileges to merge commits.
- **Merge:** The process by which commits are saved to the master code. Merges algorithm are also commits and have an author.
- **Feature Author:** The creator of an update to Bitcoin, typically in a pull request.
- **Feature Contributors:** Contributors to a pull request before it is merged.
- **Merge Author:** The maintainer who runs the pull request through the merge script and merges it.
- **Merge Commit:** A list or collection of commits and changes to the master code. Each merge commit may include multiple pull requests. Merge commits don’t update version numbers; only builds do.
- **Pull Request:** A collection of commits.

-- [Official description of contributor workflow](https://github.com/bitcoin/bitcoin/blob/master/CONTRIBUTING.md)

-- [Difference between author and committer in Git](https://stackoverflow.com/questions/18750808/difference-between-author-and-committer-in-git/18754896#18754896)

## Dependencies

TODO: These so far:

1. Ruby
2. A GitHub API key (TODO: resolve this dependency)
3. [Git](https://github.com/ruby-git/ruby-git) gem (`gem install git`)

## Roadmap
- **V1:** Proof of concept, static site.
- **V2:** Explorable site.
- **V3:** Expansion to additional Bitcoin repositories?

## Usage

Toodles


