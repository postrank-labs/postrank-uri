# PostRank URI

A collection of convenience methods (Ruby 1.8 & Ruby 1.9) for dealing with extracting, (un)escaping, normalization, and canonicalization of URIs. At PostRank we process over 20M URI associated activities each day, and we need to make sure that we can reliably extract the URIs from a variety of text formats, deal with all the numerous and creative ways users like to escape and unescape their URIs, normalize the resulting URIs, and finally apply a set of custom canonicalization rules to make sure that we can cross-reference when the users are talking about the same URL.

In a nutshell, we need to make sure that creative cases like the ones below all resolve to same URI:

 - http://igvita.com/
 - http://igvita.com///
 - http://igvita.com/../?#
 - http://igvita.com/a/../?
 - http://igvita.com/a/../?utm_source%3Danalytics
 - ... and the list goes on - check the specs.

## API

- **PostRank::URI.extract(text)** - Detect URIs in text, discard bad TLD's
- **PostRank::URI.clean(uri)** - Unescape, normalize, apply c14n filters - 95% use case.

- **PostRank::URI.normalize(uri)** - Apply RFC normalization rules, discard extra path characters, drop anchors
- **PostRank::URI.unescape(uri)** - Unescape URI entities, handle +/%20's, etc
- **PostRank::URI.escape(uri)** - Escape URI

## Example

    >> PostRank::URI.extract('some random text with http://link.to somecanadiansite.ca')
    [
        [0] "http://link.to/",
        [1] "http://somecanadiansite.ca/"
    ]

    >> PostRank::URI.clean('link.to?a=b&utm_source=FeedBurner#stuff')
    [
        [0] "http://link.to/?a=b"
    ]

## C14N

As part of URI canonicalization the library will remove common tracking parameters from Google Analytics and several other providers. Beyond that, host-specific rules are also applied. For example, nytimes.com likes to add a 'partner' query parameter for tracking purposes, but which has no effect on the content - hence, it is removed from the URI. For full list, see the c14n.yml file.

Detecting "duplicate URLs" is a hard problem to solve (expensive in all senses), instead we are compiling a manually assembled database. If you find cases which are missing, please do report them, or send us a pull request!