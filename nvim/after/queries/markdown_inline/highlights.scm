; extends

((link_destination) @markup.link.url
  (#set! spell false))

((uri_autolink) @markup.link.url
  (#set! spell false))

((email_autolink) @markup.link.url
  (#set! spell false))
