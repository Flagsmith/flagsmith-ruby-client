<a id="v4.3.0"></a>
# [v4.3.0](https://github.com/Flagsmith/flagsmith-ruby-client/releases/tag/v4.3.0) - 2024-12-06

## What's Changed
* Bump rexml from 3.2.8 to 3.3.9 by [@dependabot](https://github.com/dependabot) in [#71](https://github.com/Flagsmith/flagsmith-ruby-client/pull/71)
* fix: allow false as a flag value by [@bdchauvette](https://github.com/bdchauvette) in [#68](https://github.com/Flagsmith/flagsmith-ruby-client/pull/68)
* feat: Enable realtime mode (SSE)  by [@zachaysan](https://github.com/zachaysan) in [#73](https://github.com/Flagsmith/flagsmith-ruby-client/pull/73)
* Make segment operators nil-safe by [@rolodato](https://github.com/rolodato) in [#69](https://github.com/Flagsmith/flagsmith-ruby-client/pull/69)
* chore: Bump to 4.3.0 by [@zachaysan](https://github.com/zachaysan) in [#74](https://github.com/Flagsmith/flagsmith-ruby-client/pull/74)

## New Contributors
* [@bdchauvette](https://github.com/bdchauvette) made their first contribution in [#68](https://github.com/Flagsmith/flagsmith-ruby-client/pull/68)
* [@rolodato](https://github.com/rolodato) made their first contribution in [#69](https://github.com/Flagsmith/flagsmith-ruby-client/pull/69)

**Full Changelog**: https://github.com/Flagsmith/flagsmith-ruby-client/compare/v4.2.0...v4.3.0

[Changes][v4.3.0]


<a id="v4.2.0"></a>
# [v4.2.0](https://github.com/Flagsmith/flagsmith-ruby-client/releases/tag/v4.2.0) - 2024-10-22

## What's Changed
* feat: Support transient identities and traits by [@khvn26](https://github.com/khvn26) in [#66](https://github.com/Flagsmith/flagsmith-ruby-client/pull/66)


**Full Changelog**: https://github.com/Flagsmith/flagsmith-ruby-client/compare/v4.1.1...v4.2.0

[Changes][v4.2.0]


<a id="v4.1.1"></a>
# [v4.1.1](https://github.com/Flagsmith/flagsmith-ruby-client/releases/tag/v4.1.1) - 2024-05-22

## What's Changed
* fix: Squash exceptions for polling manager by [@zachaysan](https://github.com/zachaysan) in [#55](https://github.com/Flagsmith/flagsmith-ruby-client/pull/55)
* Bump rexml from 3.2.6 to 3.2.8 by [@dependabot](https://github.com/dependabot) in [#60](https://github.com/Flagsmith/flagsmith-ruby-client/pull/60)


**Full Changelog**: https://github.com/Flagsmith/flagsmith-ruby-client/compare/v4.1.0...v4.1.1

[Changes][v4.1.1]


<a id="v4.1.0"></a>
# [v4.1.0](https://github.com/Flagsmith/flagsmith-ruby-client/releases/tag/v4.1.0) - 2024-04-19

## What's Changed
* feat: Add identity overrides to client by [@zachaysan](https://github.com/zachaysan) in [#50](https://github.com/Flagsmith/flagsmith-ruby-client/pull/50)
* fix: Make local evaluation multivariate work by [@zachaysan](https://github.com/zachaysan) in [#51](https://github.com/Flagsmith/flagsmith-ruby-client/pull/51)
* Bump puma from 6.3.1 to 6.4.2 in /example by [@dependabot](https://github.com/dependabot) in [#39](https://github.com/Flagsmith/flagsmith-ruby-client/pull/39)
* chore: remove examples by [@dabeeeenster](https://github.com/dabeeeenster) in [#48](https://github.com/Flagsmith/flagsmith-ruby-client/pull/48)
* fix: Mute analytics processor on failure by [@zachaysan](https://github.com/zachaysan) in [#57](https://github.com/Flagsmith/flagsmith-ruby-client/pull/57)
* fix: Stop repeated calls to update environment when polling manager is set by [@zachaysan](https://github.com/zachaysan) in [#58](https://github.com/Flagsmith/flagsmith-ruby-client/pull/58)

## New Contributors
* [@dabeeeenster](https://github.com/dabeeeenster) made their first contribution in [#48](https://github.com/Flagsmith/flagsmith-ruby-client/pull/48)

**Full Changelog**: https://github.com/Flagsmith/flagsmith-ruby-client/compare/v4.0.1...v4.1.0

[Changes][v4.1.0]


<a id="v4.0.1"></a>
# [v4.0.1](https://github.com/Flagsmith/flagsmith-ruby-client/releases/tag/v4.0.1) - 2024-02-06

## What's Changed
* fix: Remove dev dependences by [@zachaysan](https://github.com/zachaysan) in [#45](https://github.com/Flagsmith/flagsmith-ruby-client/pull/45)
* chore: Bump version to 4.0.1 by [@zachaysan](https://github.com/zachaysan) in [#46](https://github.com/Flagsmith/flagsmith-ruby-client/pull/46)


**Full Changelog**: https://github.com/Flagsmith/flagsmith-ruby-client/compare/v4.0.0...v4.0.1

[Changes][v4.0.1]


<a id="v4.0.0"></a>
# [Version 4.0.0 (v4.0.0)](https://github.com/Flagsmith/flagsmith-ruby-client/releases/tag/v4.0.0) - 2024-01-30

## What's Changed
* Bump puma from 5.6.4 to 6.3.1 in /example by [@dependabot](https://github.com/dependabot) in [#35](https://github.com/Flagsmith/flagsmith-ruby-client/pull/35)
* chore: update CI Ruby version to 3.1 by [@khvn26](https://github.com/khvn26) in [#34](https://github.com/Flagsmith/flagsmith-ruby-client/pull/34)
* fix: Pin the faraday gem file to avoid TypeError superclass mismatch by [@zachaysan](https://github.com/zachaysan) in [#37](https://github.com/Flagsmith/flagsmith-ruby-client/pull/37)
* feat: Add offline mode for using the client locally by [@zachaysan](https://github.com/zachaysan) in [#38](https://github.com/Flagsmith/flagsmith-ruby-client/pull/38)
* chore: Remove faraday middleware by [@zachaysan](https://github.com/zachaysan) in [#40](https://github.com/Flagsmith/flagsmith-ruby-client/pull/40)
* chore: Bump version to 4.0.0 by [@zachaysan](https://github.com/zachaysan) in [#41](https://github.com/Flagsmith/flagsmith-ruby-client/pull/41)

## New Contributors
* [@zachaysan](https://github.com/zachaysan) made their first contribution in [#37](https://github.com/Flagsmith/flagsmith-ruby-client/pull/37)

**Full Changelog**: https://github.com/Flagsmith/flagsmith-ruby-client/compare/v3.2.0...v4.0.0

[Changes][v4.0.0]


<a id="v3.2.0"></a>
# [Version 3.2.0 (v3.2.0)](https://github.com/Flagsmith/flagsmith-ruby-client/releases/tag/v3.2.0) - 2023-07-25

## What's Changed
* Prevent publish workflow from running by [@matthewelwell](https://github.com/matthewelwell) in [#25](https://github.com/Flagsmith/flagsmith-ruby-client/pull/25)
* Bump rack from 2.2.3.1 to 2.2.6.4 in /example by [@dependabot](https://github.com/dependabot) in [#27](https://github.com/Flagsmith/flagsmith-ruby-client/pull/27)
* Update dependencies by [@matthewelwell](https://github.com/matthewelwell) in [#28](https://github.com/Flagsmith/flagsmith-ruby-client/pull/28)
* ci: add rubocop by [@matthewelwell](https://github.com/matthewelwell) in [#32](https://github.com/Flagsmith/flagsmith-ruby-client/pull/32)
* feat: implement `IN` operator by [@khvn26](https://github.com/khvn26) in [#31](https://github.com/Flagsmith/flagsmith-ruby-client/pull/31)

## New Contributors
* [@khvn26](https://github.com/khvn26) made their first contribution in [#31](https://github.com/Flagsmith/flagsmith-ruby-client/pull/31)

**Full Changelog**: https://github.com/Flagsmith/flagsmith-ruby-client/compare/v3.1.1...v3.2.0

[Changes][v3.2.0]


<a id="v3.1.1"></a>
# [Version 3.1.1 (v3.1.1)](https://github.com/Flagsmith/flagsmith-ruby-client/releases/tag/v3.1.1) - 2023-02-22

## What's Changed
* Fix analytics flush timer by [@matthewelwell](https://github.com/matthewelwell) in [#23](https://github.com/Flagsmith/flagsmith-ruby-client/pull/23)
* Release 3.1.1 by [@matthewelwell](https://github.com/matthewelwell) in [#24](https://github.com/Flagsmith/flagsmith-ruby-client/pull/24)


**Full Changelog**: https://github.com/Flagsmith/flagsmith-ruby-client/compare/v3.1.0...v3.1.1

[Changes][v3.1.1]


<a id="v3.1.0"></a>
# [Version 3.1.0 (v3.1.0)](https://github.com/Flagsmith/flagsmith-ruby-client/releases/tag/v3.1.0) - 2022-11-01

## What's Changed
* Add modulo operator by [@matthewelwell](https://github.com/matthewelwell) in [#21](https://github.com/Flagsmith/flagsmith-ruby-client/pull/21)
* Add get identity segments method by [@matthewelwell](https://github.com/matthewelwell) in [#18](https://github.com/Flagsmith/flagsmith-ruby-client/pull/18)
* Add IS_SET and IS_NOT_SET segment operators by [@matthewelwell](https://github.com/matthewelwell) in [#20](https://github.com/Flagsmith/flagsmith-ruby-client/pull/20)
* Release 3.1.0 by [@matthewelwell](https://github.com/matthewelwell) in [#19](https://github.com/Flagsmith/flagsmith-ruby-client/pull/19)


**Full Changelog**: https://github.com/Flagsmith/flagsmith-ruby-client/compare/v3.0.2...v3.1.0

[Changes][v3.1.0]


<a id="v3.0.2"></a>
# [Version 3.0.2 (v3.0.2)](https://github.com/Flagsmith/flagsmith-ruby-client/releases/tag/v3.0.2) - 2022-07-13

## What's Changed
* Use feature name instead of id for analytics by [@matthewelwell](https://github.com/matthewelwell) in [#17](https://github.com/Flagsmith/flagsmith-ruby-client/pull/17)
* Bump rack from 2.2.3 to 2.2.3.1 in /example by [@dependabot](https://github.com/dependabot) in [#12](https://github.com/Flagsmith/flagsmith-ruby-client/pull/12)
* Bump rexml from 3.2.4 to 3.2.5 by [@dependabot](https://github.com/dependabot) in [#8](https://github.com/Flagsmith/flagsmith-ruby-client/pull/8)
* Release 3.0.2 by [@matthewelwell](https://github.com/matthewelwell) in [#16](https://github.com/Flagsmith/flagsmith-ruby-client/pull/16)

## New Contributors
* [@dependabot](https://github.com/dependabot) made their first contribution in [#12](https://github.com/Flagsmith/flagsmith-ruby-client/pull/12)

**Full Changelog**: https://github.com/Flagsmith/flagsmith-ruby-client/compare/v3.0.1...v3.0.2

[Changes][v3.0.2]


<a id="v3.0.1"></a>
# [Version 3.0.1 (v3.0.1)](https://github.com/Flagsmith/flagsmith-ruby-client/releases/tag/v3.0.1) - 2022-06-09

## What's Changed
* Add BaseFlag and DefaultFlag classes by [@matthewelwell](https://github.com/matthewelwell) in [#14](https://github.com/Flagsmith/flagsmith-ruby-client/pull/14)
* Release 3.0.1 by [@matthewelwell](https://github.com/matthewelwell) in [#15](https://github.com/Flagsmith/flagsmith-ruby-client/pull/15)


**Full Changelog**: https://github.com/Flagsmith/flagsmith-ruby-client/compare/v3.0.0...v3.0.1

[Changes][v3.0.1]


<a id="v3.0.0"></a>
# [Version 3.0.0 (v3.0.0)](https://github.com/Flagsmith/flagsmith-ruby-client/releases/tag/v3.0.0) - 2022-06-07

## What's Changed
* Example app by [@byReham](https://github.com/byReham) in [#10](https://github.com/Flagsmith/flagsmith-ruby-client/pull/10)
* Update default url by [@matthewelwell](https://github.com/matthewelwell) in [#11](https://github.com/Flagsmith/flagsmith-ruby-client/pull/11)
* Release/3.0.0 by [@byReham](https://github.com/byReham) in [#9](https://github.com/Flagsmith/flagsmith-ruby-client/pull/9)

## New Contributors
* [@byReham](https://github.com/byReham) made their first contribution in [#10](https://github.com/Flagsmith/flagsmith-ruby-client/pull/10)
* [@matthewelwell](https://github.com/matthewelwell) made their first contribution in [#11](https://github.com/Flagsmith/flagsmith-ruby-client/pull/11)

**Full Changelog**: https://github.com/Flagsmith/flagsmith-ruby-client/compare/v2.0.0...v3.0.0

[Changes][v3.0.0]


[v4.3.0]: https://github.com/Flagsmith/flagsmith-ruby-client/compare/v4.2.0...v4.3.0
[v4.2.0]: https://github.com/Flagsmith/flagsmith-ruby-client/compare/v4.1.1...v4.2.0
[v4.1.1]: https://github.com/Flagsmith/flagsmith-ruby-client/compare/v4.1.0...v4.1.1
[v4.1.0]: https://github.com/Flagsmith/flagsmith-ruby-client/compare/v4.0.1...v4.1.0
[v4.0.1]: https://github.com/Flagsmith/flagsmith-ruby-client/compare/v4.0.0...v4.0.1
[v4.0.0]: https://github.com/Flagsmith/flagsmith-ruby-client/compare/v3.2.0...v4.0.0
[v3.2.0]: https://github.com/Flagsmith/flagsmith-ruby-client/compare/v3.1.1...v3.2.0
[v3.1.1]: https://github.com/Flagsmith/flagsmith-ruby-client/compare/v3.1.0...v3.1.1
[v3.1.0]: https://github.com/Flagsmith/flagsmith-ruby-client/compare/v3.0.2...v3.1.0
[v3.0.2]: https://github.com/Flagsmith/flagsmith-ruby-client/compare/v3.0.1...v3.0.2
[v3.0.1]: https://github.com/Flagsmith/flagsmith-ruby-client/compare/v3.0.0...v3.0.1
[v3.0.0]: https://github.com/Flagsmith/flagsmith-ruby-client/tree/v3.0.0

<!-- Generated by https://github.com/rhysd/changelog-from-release v3.9.0 -->
