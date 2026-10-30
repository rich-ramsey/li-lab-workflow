// Chapter-based numbering for books with appendix support
#let equation-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "(A.1)" } else { "(1.1)" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let callout-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "A.1" } else { "1.1" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let subfloat-numbering(n-super, subfloat-idx) = {
  let chapter = counter(heading).get().first()
  let pattern = if state("appendix-state", none).get() != none { "A.1a" } else { "1.1a" }
  numbering(pattern, chapter, n-super, subfloat-idx)
}
// Theorem configuration for theorion
// Chapter-based numbering (H1 = chapters)
#let theorem-inherited-levels = 1

// Appendix-aware theorem numbering
#let theorem-numbering(loc) = {
  if state("appendix-state", none).at(loc) != none { "A.1" } else { "1.1" }
}

// Theorem render function
// Note: brand-color is not available at this point in template processing
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  block(
    width: 100%,
    inset: (left: 1em),
    stroke: (left: 2pt + black),
  )[
    #if full-title != "" and full-title != auto and full-title != none {
      strong[#full-title]
      linebreak()
    }
    #body
  ]
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  let has-title-block = title != none or (authors != none and authors != ()) or date != none or abstract != none
  if has-title-block {
    place(
      top,
      float: true,
      scope: "parent",
      clearance: 4mm,
      block(below: 1em, width: 100%)[

        #if title != none {
          align(center, block(inset: 2em)[
            #set par(leading: heading-line-height) if heading-line-height != none
            #set text(font: heading-family) if heading-family != none
            #set text(weight: heading-weight)
            #set text(style: heading-style) if heading-style != "normal"
            #set text(fill: heading-color) if heading-color != black

            #text(size: title-size)[#title #if thanks != none {
              footnote(thanks, numbering: "*")
              counter(footnote).update(n => n - 1)
            }]
            #(if subtitle != none {
              parbreak()
              text(size: subtitle-size)[#subtitle]
            })
          ])
        }

        #if authors != none and authors != () {
          let count = authors.len()
          let ncols = calc.min(count, 3)
          grid(
            columns: (1fr,) * ncols,
            row-gutter: 1.5em,
            ..authors.map(author =>
                align(center)[
                  #author.name \
                  #author.affiliation \
                  #author.email
                ]
            )
          )
        }

        #if date != none {
          align(center)[#block(inset: 1em)[
            #date
          ]]
        }

        #if abstract != none {
          block(inset: 2em)[
          #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
          ]
        }
      ]
    )
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#set page(binding: auto)

#set bibliography(title: [References], style: "apa")

#show bibliography: it => {
  counter(heading).update(0)
  pagebreak()
  it
}
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "a4",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)
// Logo is handled by orange-book's cover page, not as a page background
// NOTE: marginalia.setup is called in typst-show.typ AFTER book.with()
// to ensure marginalia's margins override the book format's default margins
#import "@preview/orange-book:0.7.1": book, part, chapter, appendices

#show: book.with(
  title: [A Workflow for Experiment Planning and Data Analysis in Education Research],
  author: "Rich Ramsey",
  date: "2026-10-30",
  main-color: brand-color.at("primary", default: blue),
  logo: {
    let logo-info = brand-logo.at("medium", default: none)
    if logo-info != none { image(logo-info.path, alt: logo-info.at("alt", default: none)) }
  },
  outline-depth: 3,
)


// Reset Quarto's custom figure counters at each chapter (level-1 heading).
// Orange-book only resets kind:image and kind:table, but Quarto uses custom kinds.
// This list is generated dynamically from crossref.categories.
#show heading.where(level: 1): it => {
  counter(figure.where(kind: "quarto-float-fig")).update(0)
  counter(figure.where(kind: "quarto-float-tbl")).update(0)
  counter(figure.where(kind: "quarto-float-lst")).update(0)
  counter(figure.where(kind: "quarto-callout-Note")).update(0)
  counter(figure.where(kind: "quarto-callout-Warning")).update(0)
  counter(figure.where(kind: "quarto-callout-Caution")).update(0)
  counter(figure.where(kind: "quarto-callout-Tip")).update(0)
  counter(figure.where(kind: "quarto-callout-Important")).update(0)
  counter(math.equation).update(0)
  it
}

#heading(level: 1, numbering: none)[Preface]
<preface>
This book documents a data analysis workflow that might be useful for people in the #link("https://li.ethz.ch/")[Learning and Instruction Lab] at ETH Zürich. It might also be useful for researchers in education research more generally, as well as anyone else who analyses behavioural data from human participants.

#heading(level: 2, numbering: none)[Why this exists]
<why-this-exists>
After conversations with several lab members --- Martina R., Ipek, Charlotte, Martina V., and Christian --- a set of common themes emerged across otherwise distinct projects. Each project used a broadly similar design, collected similar types of data, and faced similar questions about planning and analysis. Rather than repeat my comments and feedback, I decided to outline my thoughts here in the form of a general workflow. The hope would be that folks in the lab will find it a useful resource for planning experiments and analysing data.

#heading(level: 2, numbering: none)[What this book covers]
<what-this-book-covers>
The book follows the natural sequence of a study from planning to inference, split into two parts.

#emph[Part 1: Before data collection:] how to use pilot data or simulations to justify a sample size (#ref(<sec-planning>, supplement: [Chapter])), and what and how to preregister (#ref(<sec-prereg>, supplement: [Chapter])).

#emph[Part 2: After data collection:] how to process and visualise data (#ref(<sec-data-processing>, supplement: [Chapter])), fit a multilevel Bayesian regression model (#ref(<sec-modelling>, supplement: [Chapter])), and generate and communicate inferences (#ref(<sec-inference>, supplement: [Chapter])).

#heading(level: 2, numbering: none)[What this book does not cover]
<what-this-book-does-not-cover>
This is deliberately a workflow document, not a methods textbook. The most important scientific decisions --- framing the theoretical context, specifying research questions, choosing appropriate measures --- are not covered here. Those decisions should come first, and nothing in this workflow substitutes for them.

#heading(level: 2, numbering: none)[A note on code]
<a-note-on-code>
All code is written in R and uses a tidyverse + CmdStan/brms stack. Slow-running chunks (model fitting, simulations) are pre-compiled; the book renders from saved outputs by default. See the reproducibility note in the README for details on refitting from scratch.

#heading(level: 2, numbering: none)[A note on data]
<a-note-on-data>
The data are simulated based on the structure and parameter estimates of a dataset collected by a lab member as part of their PhD research. The simulated data preserve the key features of the original --- sample size, design structure, effect magnitudes, and variability --- but contain no real participant data.

Simulated data are used for two reasons. First, they allow the book to be fully self-contained and publicly shareable without raising data privacy concerns. Second, because the true parameter values are known by construction, they make it easier to check that models are recovering what they should --- a useful property when the goal is to outline a data analysis and modelling workflow.

#heading(level: 2, numbering: none)[Feedback]
<feedback>
This is a first draft version of the document, and therefore I welcome constructive feedback on things that could be improved.

#heading(level: 2, numbering: none)[License and citation]
<license-and-citation>
© Rich Ramsey, ETH Zürich. Licensed under #link("https://creativecommons.org/licenses/by/4.0/")[CC BY 4.0].

#block[
#Skylighting(([#SpecialCharTok("@");#NormalTok("book{RamseyliLabworkflow2026,");],
[#NormalTok("  title ");#OtherTok("=");#NormalTok(" {A Workflow ");#ControlFlowTok("for");#NormalTok(" Experiment Planning and Data Analysis ");#ControlFlowTok("in");#NormalTok(" Education Research},");],
[#NormalTok("  author ");#OtherTok("=");#NormalTok(" {Ramsey, Richard},");],
[#NormalTok("  year ");#OtherTok("=");#NormalTok(" {");#DecValTok("2026");#NormalTok("},");],
[#NormalTok("  month ");#OtherTok("=");#NormalTok(" {");#DecValTok("10");#NormalTok("},");],
[#NormalTok("  edition ");#OtherTok("=");#NormalTok(" {version ");#FloatTok("0.1");#NormalTok("},");],
[#NormalTok("  url ");#OtherTok("=");#NormalTok(" {https");#SpecialCharTok(":");#ErrorTok("//");#NormalTok("rich");#SpecialCharTok("-");#NormalTok("ramsey.github.io");#SpecialCharTok("/");#NormalTok("li");#SpecialCharTok("-");#NormalTok("lab");#SpecialCharTok("-");#NormalTok("workflow");#SpecialCharTok("/");#NormalTok("}");],
[#NormalTok("}");],));
]
#heading(level: 2, numbering: none)[Acknowledgments]
<acknowledgments>
Many thanks to Isabel Nigsch for helpful feedback on a previous version of this project.

#part[Before data collection]
= Planning
<sec-planning>
This chapter summarises one approach to planning a study. For a good summary of various approaches to sample size planning, see this paper by Daniel Lakens @lakensSampleSizeJustification2022. Here is a table from the paper (#ref(<tbl-lakens-justification>, supplement: [Table])).

#figure([
#show figure: set block(breakable: true)

#block[ // start block

  #let style-dict = (
    // tinytable style-dict after
    "1_1": 0, "3_1": 0, "5_1": 0, "0_0": 1, "2_0": 1, "4_0": 1, "6_0": 1, "1_0": 2, "3_0": 2, "5_0": 2
  )

  #let style-array = ( 
    // tinytable cell style after
    (background: rgb("#ededed"),),
    (bold: true,),
    (bold: true, background: rgb("#ededed"),),
  )

  // Helper function to get cell style
  #let get-style(x, y) = {
    let key = str(y) + "_" + str(x)
    if key in style-dict { style-array.at(style-dict.at(key)) } else { none }
  }

  // tinytable align-default-array before
  #let align-default-array = ( left, left, ) // tinytable align-default-array here
  #show table.cell: it => {
    if style-array.len() == 0 { return it }
    
    let style = get-style(it.x, it.y)
    if style == none { return it }
    
    let tmp = it
    if ("fontsize" in style) { tmp = text(size: style.fontsize, tmp) }
    if ("color" in style) { tmp = text(fill: style.color, tmp) }
    if ("indent" in style) { tmp = pad(left: style.indent, tmp) }
    if ("underline" in style) { tmp = underline(tmp) }
    if ("italic" in style) { tmp = emph(tmp) }
    if ("bold" in style) { tmp = strong(tmp) }
    if ("mono" in style) { tmp = math.mono(tmp) }
    if ("strikeout" in style) { tmp = strike(tmp) }
    if ("smallcaps" in style) { tmp = smallcaps(tmp) }
    tmp
  }

  #align(center, [

  #table( // tinytable table start
    columns: (25.00%, 75.00%),
    stroke: none,
    rows: auto,
    align: (x, y) => {
      let style = get-style(x, y)
      if style != none and "align" in style { style.align } else { left }
    },
    fill: (x, y) => {
      let style = get-style(x, y)
      if style != none and "background" in style { style.background }
    },
 table.hline(y: 1, start: 0, end: 2, stroke: 0.05em + black),
 table.hline(y: 7, start: 0, end: 2, stroke: 0.08em + black),
 table.hline(y: 0, start: 0, end: 2, stroke: 0.08em + black),
    // tinytable lines before

    // tinytable header start
    table.header(
      repeat: true,
[Type of Justification], [When is this justification applicable?],
    ),
    // tinytable header end

    // tinytable cell content after
[Measure entire population], [A researcher can specify the entire population, it is finite, and it is possible to measure (almost) every entity in the population.],
[Resource constraints], [Limited resources are the primary reason for the choice of the sample size a researcher can collect.],
[Accuracy], [The research question focusses on the size of a parameter, and a researcher collects sufficient data to have an estimate with a desired level of accuracy.],
[A-priori power analysis], [The research question has the aim to test whether certain effect sizes can be statistically rejected with a desired statistical power.],
[Heuristics], [A researcher decides upon the sample size based on a heuristic, general rule or norm that is described in the literature, or communicated orally.],
[No justification], [A researcher has no reason to choose a specific sample size, or does not have a clearly specified inferential goal and wants to communicate this honestly.],

    // tinytable footer after

  ) // end table

  ]) // end align

] // end block
], caption: figure.caption(
position: top, 
[
Types of justification for sample size decisions, and when each applies. Adapted from Lakens (2022).
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-lakens-justification>


Based on my conversations with various people in the learning and instruction lab, as well as many folks in other psychology and human neuroscience labs, there is a discrepancy between how people say they plan studies (or how they would like to plan studies) and how they plan studies in practice. Most people try to concoct an #emph[a-prior] power analysis, since that seems to be deemed more acceptable in mainstream journals and general discourse. But scratch beneath the surface and the most common approach #emph[in practice] is the "resource constraints" approach. This is not a criticism, it is simply an observation.

The resource constraints approach targets the maximum reasonable sample size possible based on the resources available. This resource-based approach lends itself to planning via determining the minimal statistically detectable effect, or a sensitivity power analysis (rather than an #emph[a-priori] power analysis; see #ref(<tbl-lakens-evaluation>, supplement: [Table])). Using resource constraints to determine effect size sensitivity would be a lot simpler than the simulation-based approaches outlined below, as it determines the size of an effect that one could detect with a specified research design and level of statistical power. So, before you get lost digging into the weeds below, I would strongly suggest that you have a conversation with your research group about implications of a resource constraints approach within the context of your project. A resource constraints approach will save you a lot of time, and in the majority of cases it will more straightforwardly embody how your sample size is being set in practice.

And for reasonably simple designs and analyses that avoid more complex, multi-level modelling approaches, then a tool like #link("https://www.psychologie.hhu.de/arbeitsgruppen/allgemeine-psychologie-und-arbeitspsychologie/gpower")[G\*Power] can be very useful. And even if you plan on fitting a multi-level model, G\*Power can be useful to give you a quick-and-dirty ballpark estimate based on a simplified aspect of your research design. So, I would recommend becoming familiar with G\*Power.

#figure([
#show figure: set block(breakable: true)

#block[ // start block

  #let style-dict = (
    // tinytable style-dict after
    "1_1": 0, "3_1": 0, "5_1": 0, "0_0": 1, "2_0": 1, "4_0": 1, "6_0": 1, "1_0": 2, "3_0": 2, "5_0": 2
  )

  #let style-array = ( 
    // tinytable cell style after
    (background: rgb("#ededed"),),
    (bold: true,),
    (bold: true, background: rgb("#ededed"),),
  )

  // Helper function to get cell style
  #let get-style(x, y) = {
    let key = str(y) + "_" + str(x)
    if key in style-dict { style-array.at(style-dict.at(key)) } else { none }
  }

  // tinytable align-default-array before
  #let align-default-array = ( left, left, ) // tinytable align-default-array here
  #show table.cell: it => {
    if style-array.len() == 0 { return it }
    
    let style = get-style(it.x, it.y)
    if style == none { return it }
    
    let tmp = it
    if ("fontsize" in style) { tmp = text(size: style.fontsize, tmp) }
    if ("color" in style) { tmp = text(fill: style.color, tmp) }
    if ("indent" in style) { tmp = pad(left: style.indent, tmp) }
    if ("underline" in style) { tmp = underline(tmp) }
    if ("italic" in style) { tmp = emph(tmp) }
    if ("bold" in style) { tmp = strong(tmp) }
    if ("mono" in style) { tmp = math.mono(tmp) }
    if ("strikeout" in style) { tmp = strike(tmp) }
    if ("smallcaps" in style) { tmp = smallcaps(tmp) }
    tmp
  }

  #align(center, [

  #table( // tinytable table start
    columns: (25.00%, 75.00%),
    stroke: none,
    rows: auto,
    align: (x, y) => {
      let style = get-style(x, y)
      if style != none and "align" in style { style.align } else { left }
    },
    fill: (x, y) => {
      let style = get-style(x, y)
      if style != none and "background" in style { style.background }
    },
 table.hline(y: 1, start: 0, end: 2, stroke: 0.05em + black),
 table.hline(y: 7, start: 0, end: 2, stroke: 0.08em + black),
 table.hline(y: 0, start: 0, end: 2, stroke: 0.08em + black),
    // tinytable lines before

    // tinytable header start
    table.header(
      repeat: true,
[Type of Evaluation], [Which question should a researcher ask?],
    ),
    // tinytable header end

    // tinytable cell content after
[Smallest effect size of interest], [What is the smallest effect size that is considered theoretically or practically interesting?],
[The minimal statistically detectable effect], [Given the test and sample size, what is the critical effect size that can be statistically significant?],
[Expected effect size], [Which effect size is expected based on theoretical predictions or previous research?],
[Width of confidence interval], [Which effect sizes are excluded based on the expected width of the confidence interval around the effect size?],
[Sensitivity power analysis], [Across a range of possible effect sizes, which effects does a design have sufficient power to detect when performing a hypothesis test?],
[Distribution of effect sizes in a research area], [What is the empirical range of effect sizes in a specific research area, in which effects are a priori unlikely to be observed?],

    // tinytable footer after

  ) // end table

  ]) // end align

] // end block
], caption: figure.caption(
position: top, 
[
Ways to evaluate which effect sizes are interesting when planning a study. Adapted from Lakens (2022).
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-lakens-evaluation>


But, if you want to plan a study that does try to capture the nested or multi-level nature of the data, such as by allowing for variation across participants or measurement items @barrRandomEffectsStructure2013, then things get complicated fast. And we need to harness the power of data simulation. So, if you're a sucker for punishment, and if you want a more involved and simulated-based approach, then continue reading.

The approach is primarily based on two resources: a series of #link("https://solomonkurz.netlify.app/tags/power/")[blog posts] by Solomon Kurz, and an R package called #link("https://www.scienceverse.org/faux/")[{faux}] by Lisa DeBruine (see this #link("https://www.youtube.com/watch?v=O8YRgcgsk2s")[talk]). There are also many other simulation-based approaches to plan studies with multi-level models - see the bottom of this #link("https://www.scienceverse.org/faux/")[link] for details. And more generally, I would strongly recommend using data simulation more generally for a variety of reasons throughout the scientific workflow that extend beyond planning @gelman2024before@debruineUnderstandingMixedEffectsModels2021. See these #link("https://debruine.github.io/talks/EMPSEB-fake-it-2023/#/title-slide")[slides] by Lisa DeBruine for a nice summary.

The basic approach that I follow here is as follows:

+ Find existing data.
+ Fit a model to the data.
+ Use the model to guide expectations on multi-level structure.
+ Use simulations to vary parameters and guide sample size decisions.

== Read in the data and models
<read-in-the-data-and-models>
Here we use simulated data, which is based on some of Ipek's PhD data. So this is not real data, it is synthetic. But it has the structure of the dataset collected by Ipek. And this is useful when it comes to guiding expectations regarding such things as typical effect sizes and variability that one might expect from very similar research designs, measures, populations and sample sizes.

Here we read the data in and simplify the research design for the ease of this worked example.

#block[
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 5");],
[#NormalTok("  pid   item_id group   correct pre_score_z");],
[#NormalTok("  <chr>   <dbl> <fct>     <dbl>       <dbl>");],
[#NormalTok("1 P001       22 control       1       0.361");],
[#NormalTok("2 P001       23 control       1       0.361");],
[#NormalTok("3 P001       28 control       0       0.361");],
[#NormalTok("4 P001       25 control       0       0.361");],
[#NormalTok("5 P001       17 control       1       0.361");],
[#NormalTok("6 P001       19 control       0       0.361");],));
]
]
read models (if already computed, as they have been in this example project)

== Summarise and plot the data
<summarise-and-plot-the-data>
summarise

#block[
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 4");],
[#NormalTok("  pid   group    score n_items");],
[#NormalTok("  <chr> <fct>    <dbl>   <int>");],
[#NormalTok("1 P001  control      4       8");],
[#NormalTok("2 P002  control      1       8");],
[#NormalTok("3 P003  embodied     2       8");],
[#NormalTok("4 P004  control      0       8");],
[#NormalTok("5 P006  control      3       8");],
[#NormalTok("6 P007  embodied     6       8");],));
]
]
plot

#box(image("01-planning_files/figure-typst/plot-sim-data-1.svg"))

== Fit a model
<fit-a-model>
Fit a "maximal" model as specified by the design.

Maximal varying effects (varying effects are "random" effects in frequentist language) model that is specified by the design. See this paper by Barr et al., (2013) for a clear justification of taking the "maximal" approach: #link("https://www.sciencedirect.com/science/article/abs/pii/S0749596X12001180")

To help develop understanding, I will build up to the maximal model here by showing the formulas for two other models first.

+ A single level model formula. formula \<- bf(correct \~ group + pre\_score\_z)

+ Add varying intercepts by pid. formula \<- bf(correct \~ group + pre\_score\_z + (1 | pid))

+ Add varying intercepts and slopes by item\_id. formula \<- bf(correct \~ group + pre\_score\_z + (1 | pid), (1 + group | item\_id))

But in the below, we will only fit one model, using formula 3.

#block[
#Skylighting(([#NormalTok(" Family: bernoulli ");],
[#NormalTok("  Links: mu = logit ");],
[#NormalTok("Formula: correct ~ group + pre_score_z + (1 | pid) + (1 + group | item_id) ");],
[#NormalTok("   Data: sim_dat (Number of observations: 864) ");],
[#NormalTok("  Draws: 4 chains, each with iter = 4000; warmup = 2000; thin = 1;");],
[#NormalTok("         total post-warmup draws = 8000");],
[],
[#NormalTok("Multilevel Hyperparameters:");],
[#NormalTok("~item_id (Number of levels: 8) ");],
[#NormalTok("                             Estimate Est.Error l-95% CI u-95% CI Rhat Bulk_ESS");],
[#NormalTok("sd(Intercept)                    1.24      0.37     0.72     2.13 1.00     3567");],
[#NormalTok("sd(groupembodied)                0.19      0.16     0.01     0.59 1.00     5716");],
[#NormalTok("cor(Intercept,groupembodied)    -0.11      0.44    -0.85     0.74 1.00    13905");],
[#NormalTok("                             Tail_ESS");],
[#NormalTok("sd(Intercept)                    5137");],
[#NormalTok("sd(groupembodied)                4972");],
[#NormalTok("cor(Intercept,groupembodied)     6087");],
[],
[#NormalTok("~pid (Number of levels: 108) ");],
[#NormalTok("              Estimate Est.Error l-95% CI u-95% CI Rhat Bulk_ESS Tail_ESS");],
[#NormalTok("sd(Intercept)     1.03      0.14     0.76     1.34 1.00     3544     5113");],
[],
[#NormalTok("Regression Coefficients:");],
[#NormalTok("              Estimate Est.Error l-95% CI u-95% CI Rhat Bulk_ESS Tail_ESS");],
[#NormalTok("Intercept        -0.17      0.47    -1.10     0.78 1.00     2864     4051");],
[#NormalTok("groupembodied     0.15      0.27    -0.37     0.68 1.00     6588     6915");],
[#NormalTok("pre_score_z       0.31      0.13     0.06     0.56 1.00     6161     6059");],
[],
[#NormalTok("Draws were sampled using sample(hmc). For each parameter, Bulk_ESS");],
[#NormalTok("and Tail_ESS are effective sample size measures, and Rhat is the potential");],
[#NormalTok("scale reduction factor on split chains (at convergence, Rhat = 1).");],));
]
#box(image("01-planning_files/figure-typst/summary-model-b1-1.svg"))

== Understanding effect sizes under the logit link
<sec-effect-sizes>
Only read this section if you want to read more on understanding effect sizes in logisitic regression.

Before running simulations, it is worth establishing a clear mapping between the model's native parameterisation and effect sizes that are interpretable to a general audience. This section documents that mapping as a reference point for collaborators and for later simulation design.

=== The scale problem
<the-scale-problem>
Model #NormalTok("fit_b1"); uses a Bernoulli likelihood with the logit link, so all regression coefficients live on the #strong[log-odds scale]. The posterior estimate for #NormalTok("groupembodied"); is 0.15 (95% CI: −0.37, 0.68). This means that being in the embodied group increases the log-odds of a correct response by 0.15 relative to control --- a number that is essentially uninterpretable on its own.

There are three useful scales for communicating this effect, each suited to a different audience.

==== Scale 1 --- Odds ratio
<scale-1-odds-ratio>
Exponentiating the log-odds coefficient converts it to an #strong[odds ratio] (OR):

#block[
#block[
#Skylighting(([#NormalTok("[1] 1.161834");],));
]
#block[
#Skylighting(([#NormalTok("[1] 0.6907343");],));
]
#block[
#Skylighting(([#NormalTok("[1] 1.973878");],));
]
]
An OR of 1.16 means the odds of a correct response are 16% higher in the embodied group. ORs are standard in clinical and epidemiological reporting but still require some statistical literacy. Crucially, the 95% CI on the OR scale \[0.69, 1.97\] comfortably spans 1.0, reflecting the substantial uncertainty in this estimate.

==== Scale 2 --- Probability scale
<scale-2-probability-scale>
The most interpretable scale for a general audience is the #strong[probability] of a correct response. Converting from log-odds to probability requires a baseline, which is provided by the model intercept (−0.17 at #NormalTok("pre_score_z = 0");, reference group = control). The conversion uses the inverse-logit function #NormalTok("plogis()");:

#block[
#block[
#Skylighting(([#NormalTok("[1] 0.4576021");],));
]
#block[
#Skylighting(([#NormalTok("[1] 0.4950002");],));
]
]
The implied effect in plain language: at average pre-test score, the model estimates roughly #strong[46% correct in control vs.~50% correct in embodied] --- a difference of approximately 4 percentage points (Δ#emph[p] ≈ 0.04).

Note that this calculation uses fixed-effect point estimates only and ignores varying effects, so it represents the population-average probability for a hypothetical average item and participant. Individual participants and items vary substantially around this value (see the varying effects SDs in #NormalTok("summary(fit_b1)");).

==== Scale 3 --- Cohen's #emph[h]
<scale-3-cohens-h>
For collaborators accustomed to thinking in terms of Cohen's #emph[d], #strong[Cohen's h] is the natural standardised effect size for a difference between two proportions:

#block[
#block[
#Skylighting(([#NormalTok("[1] 0.08008558");],));
]
]
Conventional benchmarks for #emph[h]: 0.2 = small, 0.5 = medium, 0.8 = large. The current point estimate (#emph[h] ≈ 0.08) is well below the conventional small-effect threshold, consistent with the wide posterior credible interval.

=== Summary table
<summary-table>
The table below shows how different log-odds values translate across all three scales, anchored at the model's estimated baseline (intercept = −0.17, #emph[p]#sub[control] ≈ 0.46). These values define the simulation grid used in #ref(<sec-sims>, supplement: [Section]).

#figure([
#table(
  columns: (28.89%, 14.44%, 12.22%, 13.33%, 14.44%, 5.56%, 11.11%),
  align: (left,right,right,right,right,right,right,),
  table.header([Label], [Log-odds (β)], [Odds ratio], [p (control)], [p (embodied)], [Δp], [Cohen's h],),
  table.hline(),
  [Observed (model estimate)], [0.15], [1.16], [0.46], [0.50], [0.04], [0.08],
  [Small], [0.40], [1.49], [0.46], [0.56], [0.10], [0.20],
  [Medium], [0.87], [2.39], [0.46], [0.67], [0.21], [0.43],
  [Large], [1.39], [4.01], [0.46], [0.77], [0.31], [0.65],
)
], caption: figure.caption(
position: top, 
[
Effect size translations from log-odds to interpretable scales, anchored at the estimated baseline probability for the control group (p ≈ 0.46, corresponding to an intercept of −0.17 on the log-odds scale).
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-effect-sizes>


The simulation grid varies #NormalTok("β"); across these four levels, crossed with a range of sample sizes. The log-odds value enters the data-generating process directly; the remaining columns are reported to make clear what each simulation scenario corresponds to substantively.

== From effect sizes to posterior inference
<from-effect-sizes-to-posterior-inference>
Once a simulated dataset has been generated and a model fitted, effect sizes are recovered on the probability scale using #NormalTok("add_epred_draws()");, rather than point estimates. This properly propagates both parameter uncertainty and the varying effects structure:

Two notes on terminology worth clarifying for collaborators:

- #strong[#NormalTok("add_epred_draws()");] returns the posterior over the #emph[expected probability] --- i.e., #NormalTok("plogis(η)"); for each draw --- and is the right tool for estimating and comparing group-level probabilities. It does #emph[not] return 0/1 outcomes.

- #strong[#NormalTok("posterior_predict()");] goes one step further, drawing a 0 or 1 from #NormalTok("Bernoulli(p)"); for each draw. This adds observation-level noise on top of parameter uncertainty and is primarily useful for posterior predictive checks (e.g., #NormalTok("pp_check()");), not for effect size estimation.

=== Precision as the target, not just power
<precision-as-the-target-not-just-power>
In a Bayesian simulation study, the most natural design target is #strong[posterior precision], rather than a binary powered/underpowered verdict. Across simulation iterations, we can summarise:

- #strong[Directional accuracy]: proportion of iterations where the posterior median is in the correct direction.
- #strong[95% CI exclusion]: proportion of iterations where the 95% credible interval on Δ#emph[p] excludes zero (the NHST-adjacent criterion).
- #strong[Interval width]: mean width of the 95% CI on Δ#emph[p] across iterations --- how precisely can we estimate the accuracy difference at a given #emph[N]?

The last metric is arguably the most useful for design decisions: rather than asking "can we detect the effect?", we ask "how precisely can we characterise it?". For example, a width of ±5 percentage points on Δ#emph[p] means we can estimate the accuracy difference to within that margin, which is directly meaningful to a collaborator unfamiliar with null hypothesis testing.

== Before we simulate: key questions and considerations
<before-we-simulate-key-questions-and-considerations>
The previous section established how to read and translate the effect size estimates from model #NormalTok("fit_b1");. Before proceeding to formal simulations, it is worth pausing to ask a set of questions. This is not a mechanical step. It is a scientific one: the goal is to arrive at the simulation with a clear sense of #emph[what we are trying to learn] and #emph[what design choices are still open].

The three questions below are not independent. They have a natural dependency structure, and working through them in order prevents a common error in study planning --- optimising precision for an effect that may not be worth pursuing, or scaling up a design that could be restructured more efficiently. For some really helpful background context to effect sizes in psychological research more generally, I recommend first reading this paper by Funder and Ozer @funderEvaluatingEffectSize2019.

=== Is the effect plausibly large enough to be worth pursuing?
<is-the-effect-plausibly-large-enough-to-be-worth-pursuing>
This is the first and most important question, and it is one that pilot data with wide uncertainty can still inform to some degree. With this said, we should always keep in mind that if pilot data is based on a tiny fraction of a "typical" dataset, then it will suffer from sampling variability to a larger degree and thus provide over- or under-estimates of the true population value of interest.

The posterior estimate for the group effect in #NormalTok("fit_b1"); is β = 0.15 on the log-odds scale (95% CI: −0.37, 0.68), corresponding to Δ#emph[p] ≈ 4 percentage points at the estimated baseline. As the effect size table in #ref(<sec-effect-sizes>, supplement: [Section]) shows, even the upper bound of the credible interval (\~16pp, #emph[h] ≈ 0.32) would constitute only a small-to-moderate effect by conventional benchmarks. The lower bound is consistent with no effect or even a small negative effect.

This is not a reason to abandon the research question. But it does frame the simulation work that follows: we are not in a situation where the effect is clearly present and the only question is how much data we need to estimate it precisely. We are in a situation where we need to ask:

- What is the #strong[minimum effect size that would be theoretically meaningful] or practically relevant for this intervention? If a 4pp improvement in accuracy is too small to justify adoption, then we need a design sensitive enough to rule it #emph[out] as well as detect it when present.
- What does the #strong[wider literature] on embodied learning suggest about plausible effect magnitudes? If comparable interventions typically produce effects in the 10--20pp range, the pilot estimate is consistent with that and the question shifts to precision. If the literature suggests larger effects, the pilot may be flagging a design problem rather than a small true effect.

The simulation grid in #ref(<sec-sims>, supplement: [Section]) varies β across the range established in #ref(<sec-effect-sizes>, supplement: [Section]) precisely to avoid committing to a single assumed effect size. Power and precision are reported as a function of β or sample size, so the reader can evaluate their own substantive threshold on the resulting curves.

=== What does more data buy us, and how much more is feasible?
<what-does-more-data-buy-us-and-how-much-more-is-feasible>
Assuming the effect is worth pursuing, the next question is whether #emph[more of the same design] --- more participants, same between-person structure --- is a viable path to adequate precision.

Two features of the pilot data are relevant here.

First, the #strong[between-person variance is large]: the varying intercept SD for participants is estimated at 1.03 on the log-odds scale. This is substantial. It means there is considerable variability in overall accuracy across individuals, and this variability is pure noise in a between-person comparison --- it inflates the uncertainty around the group effect without contributing any information about it. Any between-person design is fighting against this variance.

Second, the #strong[item-level variance is also non-trivial] (SD(item intercept) = 1.24), and there is a varying slope for group across items (SD = 0.19). This means the effect of the intervention varies somewhat across items, which adds a further source of uncertainty that does not disappear with more participants.

We can already form a rough expectation before simulating: increasing N within the current between-person design will reduce uncertainty in the group effect, but the rate of return will be modest because a large share of the residual variance is structural (between persons, between items) rather than reducible by adding participants alone. The simulations in #ref(<sec-sims>, supplement: [Section]) quantify this explicitly, but the pilot data already suggest we should think carefully about whether there is a more efficient design available (see #ref(<sec-design-change>, supplement: [Section]) below).

A practical consideration also applies here: what sample sizes are actually feasible? The current dataset has 108 participants. Doubling to \~200 may be straightforward; scaling to 500+ may not be. The simulation section reports precision as a function of N across a range that spans plausible sample size, so collaborators can make an informed judgement about whether the precision gain at a given N justifies the recruitment cost.

=== Does the design itself need to change?
<sec-design-change>
This is often the highest-leverage question, and one that is easy to overlook when the default assumption is that a larger version of the current design is the natural next step.

The current design is #strong[between-person]: each participant is assigned to either the control or embodied condition, contributing data to one group only. The large between-person variance identified above (SD ≈ 1.03) is a direct cost of this design choice: individual differences in general accuracy are confounded with the group comparison, and the only way to separate them is through random assignment --- which works in expectation but leaves substantial residual uncertainty at any finite N.

A #strong[within-person (crossover) design], in which each participant experiences both conditions (on different items or at different time points), would partition out this between-person variance entirely. The "group" comparison would then be estimated from within-person differences, removing the largest single source of noise in the current model. In practical terms, this is often equivalent to running a study with substantially more participants for the same data collection effort --- though it introduces its own considerations (order effects, fatigue, item overlap). And for many research designs in psychology and education research, it is simply not possible to use a within-person design.

=== Summary: a decision sequence
<summary-a-decision-sequence>
The three questions above have a natural ordering that structures the simulation work that follows:

#figure([
#block[

#block[
#box(image("01-planning_files/figure-typst/mermaid-figure-1.png", height: 6.57in, width: 5.97in))

]

]
], caption: figure.caption(
position: bottom, 
[
A flowchart for deciding whether to simulate.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-pre-sim-flowchart>


This framing means the simulations in #ref(<sec-sims>, supplement: [Section]) are not a mechanical power calculation. They are a tool for navigating these decisions with the pilot data as a starting point, and the effect size table in #ref(<sec-effect-sizes>, supplement: [Section]) as the reference for what "large enough" means in interpretable units.

== Run some simulations
<sec-sims>
=== Background sources
<background-sources>
The basic structure and code follows the examples outlined by Solomon Kurz in his 'power' blog #link("https://solomonkurz.netlify.app/tags/power/")[posts], and Lisa DeBruine's R package #link("https://www.scienceverse.org/faux/")[faux{}] @debruineUnderstandingMixedEffectsModels2021. The faux package #link("https://www.scienceverse.org/faux/articles/")[vignettes] are particularly useful and worthwhile working through.

You could also look at these examples by Rich, which show how you might simulate multi-level data for a range of factorial designs: #link("https://github.com/rich-ramsey/sim_demo").

=== General approach
<general-approach>
The basic workflow is as follows:

+ Fit a regression model to data (real or simulated).
+ Use the regression model parameters to simulate new data.
+ Write a function to create 100s or 1000s of datasets and vary parameters of interest (e.g., sample size, trial count, effect size).
+ Summarise the simulated data to estimate likely power or precision of the various research designs.

=== Simulate one dataset
<simulate-one-dataset>
==== A simplified example to show the process
<a-simplified-example-to-show-the-process>
Let's just pretend that this is a single level model (no varying effects) with two groups and one testing time. Maybe not a sensible design, but useful for thinking about simulating data. There are just two fixed effects. b0 - intercept (control group) and b1 (embodied group estimate).

#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 7");],
[#NormalTok("  subj    item  group   group_contrast     y  prob correct");],
[#NormalTok("  <chr>   <chr> <fct>            <dbl> <dbl> <dbl>   <int>");],
[#NormalTok("1 subj001 item1 control              0 -0.17 0.458       0");],
[#NormalTok("2 subj001 item2 control              0 -0.17 0.458       0");],
[#NormalTok("3 subj001 item3 control              0 -0.17 0.458       1");],
[#NormalTok("4 subj001 item4 control              0 -0.17 0.458       1");],
[#NormalTok("5 subj001 item5 control              0 -0.17 0.458       0");],
[#NormalTok("6 subj001 item6 control              0 -0.17 0.458       1");],));
]
#box(image("01-planning_files/figure-typst/create-d0-1.svg"))

#block[
#box(image("01-planning_files/figure-typst/create-d0-2.svg"))

]
The point here is just to see that a "fixed effect only" model has the same probability estimate for all participants (dots in the plot) and all items (facets in the plot). That is nothing new, it merely shows what a fixed-effects only model is doing. And it makes clear the relatively unrealistic assumptions that that kind of model entails. It is not that these models cannot be useful, just that when you study human beings, as well as a variety of different stimuli/items, they are likely to be more variable. And for this kind of fixed-effects only model, if you are ok with using frequentist stats, then a programme like G\*Power would be fine to give you a ballpark estimate of power. But in most cases, a more complex model would seem better suited to studying human behaviour @barrRandomEffectsStructure2013@mcelreathStatisticalRethinkingBayesian2020.

==== A more realistic model
<a-more-realistic-model>
We already have the model object (fit\_b1) fitted to existing data, so (1) in the above workflow has been completed.

Look at the model as a reminder

#block[
#block[
#Skylighting(([#NormalTok(" Family: bernoulli ");],
[#NormalTok("  Links: mu = logit ");],
[#NormalTok("Formula: correct ~ group + pre_score_z + (1 | pid) + (1 + group | item_id) ");],
[#NormalTok("   Data: sim_dat (Number of observations: 864) ");],
[#NormalTok("  Draws: 4 chains, each with iter = 4000; warmup = 2000; thin = 1;");],
[#NormalTok("         total post-warmup draws = 8000");],
[],
[#NormalTok("Multilevel Hyperparameters:");],
[#NormalTok("~item_id (Number of levels: 8) ");],
[#NormalTok("                             Estimate Est.Error l-95% CI u-95% CI Rhat Bulk_ESS");],
[#NormalTok("sd(Intercept)                    1.24      0.37     0.72     2.13 1.00     3567");],
[#NormalTok("sd(groupembodied)                0.19      0.16     0.01     0.59 1.00     5716");],
[#NormalTok("cor(Intercept,groupembodied)    -0.11      0.44    -0.85     0.74 1.00    13905");],
[#NormalTok("                             Tail_ESS");],
[#NormalTok("sd(Intercept)                    5137");],
[#NormalTok("sd(groupembodied)                4972");],
[#NormalTok("cor(Intercept,groupembodied)     6087");],
[],
[#NormalTok("~pid (Number of levels: 108) ");],
[#NormalTok("              Estimate Est.Error l-95% CI u-95% CI Rhat Bulk_ESS Tail_ESS");],
[#NormalTok("sd(Intercept)     1.03      0.14     0.76     1.34 1.00     3544     5113");],
[],
[#NormalTok("Regression Coefficients:");],
[#NormalTok("              Estimate Est.Error l-95% CI u-95% CI Rhat Bulk_ESS Tail_ESS");],
[#NormalTok("Intercept        -0.17      0.47    -1.10     0.78 1.00     2864     4051");],
[#NormalTok("groupembodied     0.15      0.27    -0.37     0.68 1.00     6588     6915");],
[#NormalTok("pre_score_z       0.31      0.13     0.06     0.56 1.00     6161     6059");],
[],
[#NormalTok("Draws were sampled using sample(hmc). For each parameter, Bulk_ESS");],
[#NormalTok("and Tail_ESS are effective sample size measures, and Rhat is the potential");],
[#NormalTok("scale reduction factor on split chains (at convergence, Rhat = 1).");],));
]
]
set some values based on the model

Create the data using faux

#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 11");],
[#NormalTok("  subj    item  group   group_contrast   u0s pre_score_z      u0i     u1i      y");],
[#NormalTok("  <chr>   <chr> <fct>            <dbl> <dbl>       <dbl>    <dbl>   <dbl>  <dbl>");],
[#NormalTok("1 subj001 item1 control              0 0.645      -0.384  0.387    0.212   0.743");],
[#NormalTok("2 subj001 item2 control              0 0.645      -0.384  1.55    -0.367   1.90 ");],
[#NormalTok("3 subj001 item3 control              0 0.645      -0.384 -0.795    0.0763 -0.439");],
[#NormalTok("4 subj001 item4 control              0 0.645      -0.384  0.0607   0.302   0.417");],
[#NormalTok("5 subj001 item5 control              0 0.645      -0.384  2.15    -0.0743  2.50 ");],
[#NormalTok("6 subj001 item6 control              0 0.645      -0.384 -0.00350 -0.0496  0.353");],
[#NormalTok("# ℹ 2 more variables: prob <dbl>, correct <int>");],));
]
#box(image("01-planning_files/figure-typst/create-d1-1.svg"))

and some notes of the params

#figure([
#table(
  columns: (13.82%, 17.51%, 11.98%, 56.68%),
  align: (left,left,left,left,),
  table.header([Term], [Type], [Value], [Interpretation],),
  table.hline(),
  [#NormalTok("b0");], [Fixed effect], [-0.17], [Average log-odds of correct for a control participant on an average item with average pre-score],
  [#NormalTok("u0s");], [Varying effect (subject)], [SD = 1.03], [This participant's deviation from average --- are they generally more or less accurate?],
  [#NormalTok("u0i");], [Varying effect (item)], [SD = 1.24], [This item's deviation from average --- is it generally harder or easier?],
  [#NormalTok("(b1 + u1i) * group_contrast");], [Fixed + varying effect (group × item)], [b1 = 0.15, SD(u1i) = 0.19], [The group effect: average across items (b1) plus this item's specific deviation (u1i), active only when group\_contrast = 1],
  [#NormalTok("b2 * pre_score_z");], [Fixed effect (covariate)], [b2 = 0.31], [Pre-test score contribution --- each SD shift in pre-score moves log-odds by 0.31],
)
], caption: figure.caption(
position: top, 
[
Decomposition of the linear predictor in the data-generating process. Each term corresponds directly to a parameter estimated by model #NormalTok("fit_b1");. group\_contrast = 0 for control participants, so the entire group effect term drops out for that group.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-dgp-terms>


=== Fit a model to the simulated data d1
<fit-a-model-to-the-simulated-data-d1>
Here we fit a model and look at the output.

and now we can update the fit to save time

#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 11");],
[#NormalTok("  subj    item  group   group_contrast   u0s pre_score_z    u0i      u1i       y");],
[#NormalTok("  <chr>   <chr> <fct>            <dbl> <dbl>       <dbl>  <dbl>    <dbl>   <dbl>");],
[#NormalTok("1 subj001 item1 control              0 0.924       0.421 -1.51   0.0127  -0.622 ");],
[#NormalTok("2 subj001 item2 control              0 0.924       0.421  1.64  -0.117    2.53  ");],
[#NormalTok("3 subj001 item3 control              0 0.924       0.421  1.41  -0.00742  2.30  ");],
[#NormalTok("4 subj001 item4 control              0 0.924       0.421 -2.08  -0.133   -1.20  ");],
[#NormalTok("5 subj001 item5 control              0 0.924       0.421 -0.492  0.0791   0.392 ");],
[#NormalTok("6 subj001 item6 control              0 0.924       0.421 -0.895 -0.411   -0.0101");],
[#NormalTok("# ℹ 2 more variables: prob <dbl>, correct <int>");],));
]
#box(image("01-planning_files/figure-typst/create-d2-1.svg"))

and now update the fit - this is probably unnecessary here, as the model fits are fast anyway. But it would be useful for fits that take a longer period of time.

=== Create a function to simulate and fit multiple datasets
<create-a-function-to-simulate-and-fit-multiple-datasets>
Here's a quick example of how our function works.

=== Iterate through multiple sims
<iterate-through-multiple-sims>
let's scale it up to multiple reps and only save the parameters of interest rather than the full brms model and the data.

Note 1: the advantage of not saving the brms model and data is that it saves memory, which can easily be exhausted with 1000s of sims. The disadvantage is that you data and models cannot be explored/summarised afterwards because they are not kept.

Note 2: model size/complexity of course determines how long this process will take. e.g., if a model takes 10s, 1 minute or 5 hours to build, then there are legitimate constraints placed on simulations and maybe using a HPC like Euler might be useful.

== Let's look at the output
<lets-look-at-the-output>
=== Quick plots and summaries
<quick-plots-and-summaries>
#box(image("01-planning_files/figure-typst/plot-params-1.svg"))

#block[
#box(image("01-planning_files/figure-typst/plot-params-2.svg"))

]
#block[
#box(image("01-planning_files/figure-typst/plot-params-3.svg"))

]
ok, at this point the parameter recovery looks sensible, such that the distributions nicely overlap their target values.

But what about statistical "power" or precision?

=== Calculate power i.e., % Q2.5 \> 0
<calculate-power-i.e.-q2.5-0>
#block[
#block[
#Skylighting(([#NormalTok("# A tibble: 12 × 3");],
[#NormalTok("   subj_n b1     power");],
[#NormalTok("   <fct>  <fct>  <dbl>");],
[#NormalTok(" 1 100    0.15  0.0300");],
[#NormalTok(" 2 100    0.4   0.230 ");],
[#NormalTok(" 3 100    0.87  0.74  ");],
[#NormalTok(" 4 100    1.39  1     ");],
[#NormalTok(" 5 150    0.15  0.050 ");],
[#NormalTok(" 6 150    0.4   0.36  ");],
[#NormalTok(" 7 150    0.87  0.9   ");],
[#NormalTok(" 8 150    1.39  1     ");],
[#NormalTok(" 9 200    0.15  0.050 ");],
[#NormalTok("10 200    0.4   0.4   ");],
[#NormalTok("11 200    0.87  1     ");],
[#NormalTok("12 200    1.39  1     ");],));
]
]
plot power

#box(image("01-planning_files/figure-typst/plot-power-1.svg"))

plot parameters and include power as a text label

wrangle

#block[
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 10");],
[#NormalTok("    rep subj_n b1    parameter  Estimate Est.Error   Q2.5 Q97.5 below_zero power");],
[#NormalTok("  <dbl> <fct>  <fct> <chr>         <dbl>     <dbl>  <dbl> <dbl> <fct>      <dbl>");],
[#NormalTok("1     1 100    0.15  groupembo…   -0.248     0.319 -0.871 0.383 yes            3");],
[#NormalTok("2     1 100    0.4   groupembo…    0.319     0.318 -0.305 0.949 yes           23");],
[#NormalTok("3     1 100    0.87  groupembo…    0.930     0.270  0.396 1.47  no            74");],
[#NormalTok("4     1 100    1.39  groupembo…    1.19      0.324  0.568 1.83  no           100");],
[#NormalTok("5     1 150    0.15  groupembo…    0.283     0.286 -0.280 0.845 yes            5");],
[#NormalTok("6     1 150    0.4   groupembo…    0.291     0.274 -0.260 0.831 yes           36");],));
]
]
plot

#box(image("01-planning_files/figure-typst/plot-params-per-sim-1.svg"))

=== Let's now consider widths and precision, rather than NHST and power
<lets-now-consider-widths-and-precision-rather-than-nhst-and-power>
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 9");],
[#NormalTok("    rep subj_n b1    parameter     Estimate Est.Error   Q2.5  Q97.5  rank");],
[#NormalTok("  <dbl> <fct>  <fct> <chr>            <dbl>     <dbl>  <dbl>  <dbl> <int>");],
[#NormalTok("1    33 100    0.15  groupembodied   -0.537     0.292 -1.12  0.0504     1");],
[#NormalTok("2    29 100    0.15  groupembodied   -0.292     0.340 -0.960 0.376      2");],
[#NormalTok("3    60 100    0.15  groupembodied   -0.379     0.283 -0.925 0.190      3");],
[#NormalTok("4    70 100    0.15  groupembodied   -0.329     0.294 -0.905 0.247      4");],
[#NormalTok("5    32 100    0.15  groupembodied   -0.302     0.293 -0.889 0.271      5");],
[#NormalTok("6    99 100    0.15  groupembodied   -0.333     0.281 -0.888 0.218      6");],));
]
#box(image("01-planning_files/figure-typst/plot-lower-q-1.svg"))

This arrangement highlights the differences in widths among the intervals. The wider the interval, the less precise the estimate. Some intervals were wider than others, but all tended to hover in a similar range. We might quantify those ranges by computing a width variable.

#block[
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 10");],
[#NormalTok("    rep subj_n b1    parameter     Estimate Est.Error   Q2.5  Q97.5  rank width");],
[#NormalTok("  <dbl> <fct>  <fct> <chr>            <dbl>     <dbl>  <dbl>  <dbl> <int> <dbl>");],
[#NormalTok("1    33 100    0.15  groupembodied   -0.537     0.292 -1.12  0.0504     1  1.17");],
[#NormalTok("2    29 100    0.15  groupembodied   -0.292     0.340 -0.960 0.376      2  1.34");],
[#NormalTok("3    60 100    0.15  groupembodied   -0.379     0.283 -0.925 0.190      3  1.11");],
[#NormalTok("4    70 100    0.15  groupembodied   -0.329     0.294 -0.905 0.247      4  1.15");],
[#NormalTok("5    32 100    0.15  groupembodied   -0.302     0.293 -0.889 0.271      5  1.16");],
[#NormalTok("6    99 100    0.15  groupembodied   -0.333     0.281 -0.888 0.218      6  1.11");],));
]
]
Here's the width distribution.

#box(image("01-planning_files/figure-typst/plot-width-hist-1.svg"))

Instead of focusing on rejecting a null hypothesis, we might instead use our simulation skills to determine the sample size we need to have most of our 95% intervals come in at a certain level of precision. This has been termed the accuracy in parameter estimation \[AIPE; Maxwell et al.(2008); see also Kruschke (2015)\] approach to sample size planning.

Thinking in terms of AIPE, in terms of precision, let's say we wanted widths of 1.2, 1.0, 0.8 or smaller. These are just arbitrary values based on the output of the sims so far. For instance, there is no inherent meaning to these widths outside of the research context and typical precision that is expected. Here's how we did with our sims.

#block[
#block[
#Skylighting(([#NormalTok("# A tibble: 12 × 5");],
[#NormalTok("   b1    subj_n power_12 power_10 power_08");],
[#NormalTok("   <fct> <fct>     <dbl>    <dbl>    <dbl>");],
[#NormalTok(" 1 0.15  100        0.71   0.0400  0      ");],
[#NormalTok(" 2 0.15  150        0.98   0.67    0      ");],
[#NormalTok(" 3 0.15  200        0.98   0.91    0.34   ");],
[#NormalTok(" 4 0.4   100        0.59   0.08    0      ");],
[#NormalTok(" 5 0.4   150        0.99   0.63    0.03   ");],
[#NormalTok(" 6 0.4   200        0.98   0.89    0.25   ");],
[#NormalTok(" 7 0.87  100        0.57   0.0300  0      ");],
[#NormalTok(" 8 0.87  150        0.98   0.58    0.01000");],
[#NormalTok(" 9 0.87  200        1      0.89    0.25   ");],
[#NormalTok("10 1.39  100        0.44   0.03    0      ");],
[#NormalTok("11 1.39  150        0.94   0.45    0      ");],
[#NormalTok("12 1.39  200        0.98   0.87    0.08   ");],));
]
]
ok, at N=150 per group (or higher), widths \< 1.2 look good. 1.0 and .8 look much worse.

This simulation suggests we have a high probability of achieving 95% CI widths of 1.2 or smaller with n=150 or higher.

#block[
#block[
#Skylighting(([#NormalTok("# A tibble: 12 × 3");],
[#NormalTok("   b1    subj_n avg_width");],
[#NormalTok("   <fct> <fct>      <dbl>");],
[#NormalTok(" 1 0.15  100        1.16 ");],
[#NormalTok(" 2 0.15  150        0.974");],
[#NormalTok(" 3 0.15  200        0.857");],
[#NormalTok(" 4 0.4   100        1.17 ");],
[#NormalTok(" 5 0.4   150        0.974");],
[#NormalTok(" 6 0.4   200        0.877");],
[#NormalTok(" 7 0.87  100        1.20 ");],
[#NormalTok(" 8 0.87  150        0.992");],
[#NormalTok(" 9 0.87  200        0.868");],
[#NormalTok("10 1.39  100        1.22 ");],
[#NormalTok("11 1.39  150        1.02 ");],
[#NormalTok("12 1.39  200        0.915");],));
]
]
ok, so the average for N=150 is between is around 1 on average. That would mean that an effect of 0.5 could be distinguished consistently from zero. But of course, this would need some thinking about more generally.

= Preregistration
<sec-prereg>
There are many different ways to pre-register a study, such as a #link("https://help.osf.io/article/330-welcome-to-registrations")[pre-registration vs a registered report]. And there are different philosophies of how to approach pre-registration, in terms of the amount of depth and detail required. See the following link for a justification and an example of a #link("https://datacolada.org/64")[minimalist approach to pre-registration]. A minimalist approach is not always possible, but I do like the idea of stripping the experiment back to the key verifiable aspects, and leaving the justification for the introduction to the paper.

You should also ask yourself if you need to preregister the study based on the aims and objectives of the science. Preregistation has these benefits by design - it prevents p-hacking, HARKing, publication bias and places constraints on underpowered studies @scheelExcessPositiveResults2021@lakensBenefitsPreregistrationRegistered2024. But it is not magic. You could still pre-register a fundamentally flawed study, simply because you can pre-register #emph[anything].

I think the key point is that it adds an objective and verifiable aspect of transparency, which formally links thinking before and after the data were collected. And in my experience over the last \~10 years or so working with PhD students and postdocs on pre-registrations, the biggest win is that it forces everyone to address concrete questions about the links between research questions, hypotheses, analyses, and inference #strong[BEFORE] you collect the data. It moves the timeline and the type of conversation between team members from a more diffuse and abstract sense of this is the general research question, design and type of analysis to what #strong[EXACTLY] will we do and how will we analyse the data to evaluate our hypotheses. So, in my experience, it is an extremely valuable process to go through as a scientific team.

But not all science needs to be pre-registered. This should be an obvious point. If you are trying to generate hypotheses to test in the future then there may well be no need to pre-register anything. Likewise, if you are working from a computational or mathematical model of a system, which is in the public domain, and which generates explicit hypotheses, then you could simply refer to that model as the foundation for your hypotheses. Alternatively, maybe the approach to science that you are using is an iterative, model building exercise, which emerges more organically and cannot be boiled down to a snapshot of questions and hypotheses. This is all fine.

I would just say that for the vast majority of contemporary research in psychological and brain science, as well as related disciplines, preregistrations can and should be a sensible default expectation. But this statement probably says as much about the dominant monoculture of modern psychological and brain science, rather than the universal need for preregistration. In other words, I think science would be far better served by a broader and more diverse research base. But until then, preregistration will probably serve a useful purpose for many active researchers.

And you can pre-register exploratory work also, and this is not a contradiction. It is not necessary to pre-register exploratory work, but it could have advantages. As one example, if you have a question in mind, and you plan to access a large secondary dataset to address the question, it might be worth pre-registering your intent, if not an exact and specific analysis pipeline. This intent might be that of the 2000 variables available in the dataset, you only have interest in 12 to address your stated research question.

Below is a template, which is borrowed from #link("https://osf.io/t3xw8/files/fqs6j")[James Bartlett], which can be completed as a quarto document and then published as a pdf (or whatever other format you want) and then submitted to a preregistration website. Here is a video of James explaining the #link("https://www.youtube.com/watch?v=VdhtdsKtac0")[process]. The general approach would be to setup a quarto template doc, and then for each new study, complete the sections, generate a pdf and then submit that to your preferred pre-registration site. Then keep those documents in your project folder too. The template below is largely left empty at this stage, just to show the process.

== A pre-registration template
<a-pre-registration-template>
=== Study Information
<study-information>
+ Title

Title here.

#block[
#set enum(numbering: "1.", start: 2)
+ Authorship
]

Author 1#super[1]

Author 2#super[1]

#super[1] ETH Zürich

#block[
#set enum(numbering: "1.", start: 3)
+ Description
]

#block[
#set enum(numbering: "1.", start: 4)
+ Hypotheses
]

=== Design Plan
<design-plan>
#block[
#set enum(numbering: "1.", start: 5)
+ Study Type
]

- Experiment - A researcher randomly assigns treatments to study subjects, this includes field or lab experiments. This is also known as an intervention experiment and includes randomized controlled trials.

#block[
#set enum(numbering: "1.", start: 6)
+ Blinding
]

#block[
#set enum(numbering: "1.", start: 7)
+ Is there any additional blinding in this study?
]

#block[
#set enum(numbering: "1.", start: 8)
+ Study design
]

#block[
#set enum(numbering: "1.", start: 9)
+ Randomization
]

=== Sampling Plan
<sampling-plan>
#block[
#set enum(numbering: "1.", start: 10)
+ Existing data
]

- Registration prior to creation of data: As of the date of submission of this research plan for preregistration, the data have not yet been collected, created, or realized.

#block[
#set enum(numbering: "1.", start: 11)
+ Explanation of existing data
]

#block[
#set enum(numbering: "1.", start: 12)
+ Data collection procedures
]

#block[
#set enum(numbering: "1.", start: 13)
+ Sample size
]

#block[
#set enum(numbering: "1.", start: 14)
+ Sample size rationale
]

#block[
#set enum(numbering: "1.", start: 15)
+ Stopping rule
]

=== Variables
<variables>
#block[
#set enum(numbering: "1.", start: 16)
+ Manipulated variables
]

#block[
#set enum(numbering: "1.", start: 17)
+ Measured variables
]

#block[
#set enum(numbering: "1.", start: 18)
+ Indices
]

=== Analysis Plan
<analysis-plan>
#block[
#set enum(numbering: "1.", start: 19)
+ Statistical models
]

#block[
#set enum(numbering: "1.", start: 20)
+ Transformations
]

#block[
#set enum(numbering: "1.", start: 21)
+ Inference criteria
]

#block[
#set enum(numbering: "1.", start: 22)
+ Data exclusion
]

#block[
#set enum(numbering: "1.", start: 23)
+ Missing data
]

#block[
#set enum(numbering: "1.", start: 24)
+ Exploratory analysis
]

=== Other
<other>
#block[
#set enum(numbering: "1.", start: 25)
+ Other
]

=== References
<references>
#part[After data collection]
= Data processing
<sec-data-processing>
This chapter uses #link("https://tidyverse.org/")[#NormalTok("tidyverse");] tools to wrangle the data to re-shape it, plot it, create summary data and get it ready for modelling.

The basic structure here is as follows:

+ Read in wide format data.
+ Wrangle to re-shape it into long format.
+ Filter and create factors.
+ Run some data checks.
+ Plot the data.
+ Save our the data ready for modelling.

== Read in the data
<read-in-the-data>
#block[
#Skylighting(([#NormalTok("dat_wide ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");],
[#NormalTok("  ");#StringTok("\"data/sim_dat_wide.csv\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("show_col_types =");#NormalTok(" ");#ConstantTok("FALSE");],
[#NormalTok(")");],
[],
[#FunctionTok("head");#NormalTok("(dat_wide)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 12");],
[#NormalTok("  pid   group    test_time pre_score_z item_22 item_23 item_28 item_17 item_1");],
[#NormalTok("  <chr> <chr>    <chr>           <dbl>   <dbl>   <dbl>   <dbl>   <dbl>  <dbl>");],
[#NormalTok("1 P001  control  post            0.361       0       1       1       1      0");],
[#NormalTok("2 P002  control  post            1.33        1       1       0       0      1");],
[#NormalTok("3 P003  embodied post           -0.608       1       1       0       0      0");],
[#NormalTok("4 P004  control  post           -1.09        0       0       0       0      0");],
[#NormalTok("5 P006  control  post           -0.124       1       1       1       0      0");],
[#NormalTok("6 P007  embodied post           -0.608       1       1       1       1      1");],
[#NormalTok("# ℹ 3 more variables: item_26 <dbl>, item_25 <dbl>, item_19 <dbl>");],));
]
#Skylighting(([#CommentTok("# glimpse(dat_wide)");],
[#CommentTok("# summary(dat_wide)");],));
]
== Reshape from wide to long
<reshape-from-wide-to-long>
#block[
#Skylighting(([#NormalTok("dat_long ");#OtherTok("<-");#NormalTok(" dat_wide ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("pivot_longer");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("cols =");#NormalTok(" ");#FunctionTok("starts_with");#NormalTok("(");#StringTok("\"item_\"");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok("names_to =");#NormalTok(" ");#StringTok("\"item_id\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("names_prefix =");#NormalTok(" ");#StringTok("\"item_\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("values_to =");#NormalTok(" ");#StringTok("\"correct\"");],
[#NormalTok("  ) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");#AttributeTok("item_id =");#NormalTok(" ");#FunctionTok("as.numeric");#NormalTok("(item_id)) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("relocate");#NormalTok("(item_id, ");#AttributeTok(".after =");#NormalTok(" ");#StringTok("\"pid\"");#NormalTok(")");],
[],
[#FunctionTok("head");#NormalTok("(dat_long)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 6");],
[#NormalTok("  pid   item_id group   test_time pre_score_z correct");],
[#NormalTok("  <chr>   <dbl> <chr>   <chr>           <dbl>   <dbl>");],
[#NormalTok("1 P001       22 control post            0.361       0");],
[#NormalTok("2 P001       23 control post            0.361       1");],
[#NormalTok("3 P001       28 control post            0.361       1");],
[#NormalTok("4 P001       17 control post            0.361       1");],
[#NormalTok("5 P001        1 control post            0.361       0");],
[#NormalTok("6 P001       26 control post            0.361       0");],));
]
#Skylighting(([#CommentTok("# glimpse(dat_long)");],
[#CommentTok("# summary(dat_long)");],));
]
== Filter and create factors for plotting
<filter-and-create-factors-for-plotting>
#block[
#Skylighting(([#NormalTok("dat ");#OtherTok("<-");#NormalTok(" dat_long ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("filter");#NormalTok("(test_time ");#SpecialCharTok("==");#NormalTok(" ");#StringTok("\"delay\"");#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("select");#NormalTok("(");#SpecialCharTok("-");#NormalTok("test_time) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("group =");#NormalTok(" ");#FunctionTok("factor");#NormalTok("(");],
[#NormalTok("      group,");],
[#NormalTok("      ");#AttributeTok("levels =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"control\"");#NormalTok(", ");#StringTok("\"embodied\"");#NormalTok(")");],
[#NormalTok("    )");],
[#NormalTok("  )");],
[],
[#FunctionTok("head");#NormalTok("(dat)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 5");],
[#NormalTok("  pid   item_id group   pre_score_z correct");],
[#NormalTok("  <chr>   <dbl> <fct>         <dbl>   <dbl>");],
[#NormalTok("1 P001       22 control       0.361       1");],
[#NormalTok("2 P001       23 control       0.361       1");],
[#NormalTok("3 P001       28 control       0.361       0");],
[#NormalTok("4 P001       17 control       0.361       1");],
[#NormalTok("5 P001        1 control       0.361       0");],
[#NormalTok("6 P001       26 control       0.361       1");],));
]
]
== Run some data checks
<run-some-data-checks>
At this point, it would be worth running some checks on the data. This will almost always involve data visualisation at the same time.

Basic checks might be:

- how many pids and trials per group?
- Are there any implausible values? e.g., values outside of a sensible range, given the measure?
- Any missing data?
- Ceiling or floor effects per pid or item?
- What do the data distributions look like? Density/Histrograms would be useful.
- Have exclusion criteria been applied accurately and as per the pre-registration (if one exists)?

There will also be a bunch of other very sensible things that you should check and plot. And this is the engine room of data analysis, so seeking advice on good data hygiene and principles for data cleaning would be a good idea.

== Plot the data
<plot-the-data>
And now summarise and plot

#block[
#Skylighting(([#NormalTok("dat_summary ");#OtherTok("<-");#NormalTok(" dat ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("filter");#NormalTok("(");#SpecialCharTok("!");#FunctionTok("is.na");#NormalTok("(correct)) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("summarise");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("score =");#NormalTok(" ");#FunctionTok("sum");#NormalTok("(correct),");],
[#NormalTok("    ");#AttributeTok("n_items =");#NormalTok(" ");#FunctionTok("n");#NormalTok("(),");],
[#NormalTok("    ");#AttributeTok(".by =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(pid, group)");],
[#NormalTok("  ) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("arrange");#NormalTok("(pid, group)");],
[],
[#FunctionTok("head");#NormalTok("(dat_summary)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 4");],
[#NormalTok("  pid   group    score n_items");],
[#NormalTok("  <chr> <fct>    <dbl>   <int>");],
[#NormalTok("1 P001  control      4       8");],
[#NormalTok("2 P002  control      1       8");],
[#NormalTok("3 P003  embodied     2       8");],
[#NormalTok("4 P004  control      0       8");],
[#NormalTok("5 P006  control      3       8");],
[#NormalTok("6 P007  embodied     6       8");],));
]
]
#Skylighting(([#NormalTok("group_colours ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#AttributeTok("control =");#NormalTok(" ");#StringTok("\"#4477AA\"");#NormalTok(", ");#AttributeTok("embodied =");#NormalTok(" ");#StringTok("\"#228833\"");#NormalTok(")");],
[],
[#NormalTok("p1 ");#OtherTok("<-");#NormalTok(" dat_summary ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("ggplot");#NormalTok("(");#FunctionTok("aes");#NormalTok("(");#AttributeTok("y =");#NormalTok(" score, ");#AttributeTok("fill =");#NormalTok(" group, ");#AttributeTok("colour =");#NormalTok(" group)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#CommentTok("# histogram slab nudged right");],
[#NormalTok("  ");#FunctionTok("stat_slab");#NormalTok("(");],
[#NormalTok("    ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#FunctionTok("as.numeric");#NormalTok("(group) ");#SpecialCharTok("+");#NormalTok(" ");#FloatTok("0.05");#NormalTok(", ");#AttributeTok("thickness =");#NormalTok(" ");#FunctionTok("after_stat");#NormalTok("(pdf)),");],
[#NormalTok("    ");#AttributeTok("side =");#NormalTok(" ");#StringTok("\"right\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("scale =");#NormalTok(" ");#FloatTok("0.4");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.5");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("density =");#NormalTok(" ");#StringTok("\"histogram\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("breaks =");#NormalTok(" ");#FunctionTok("breaks_fixed");#NormalTok("(");#AttributeTok("width =");#NormalTok(" ");#DecValTok("1");#NormalTok(")");],
[#NormalTok("  ) ");#SpecialCharTok("+");],
[#NormalTok("  ");#CommentTok("# dots nudged left with jitter");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("(");],
[#NormalTok("    ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#FunctionTok("as.numeric");#NormalTok("(group) ");#SpecialCharTok("-");#NormalTok(" ");#FloatTok("0.15");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok("position =");#NormalTok(" ");#FunctionTok("position_jitter");#NormalTok("(");#AttributeTok("width =");#NormalTok(" ");#FloatTok("0.1");#NormalTok(", ");#AttributeTok("height =");#NormalTok(" ");#DecValTok("0");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.4");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("size =");#NormalTok(" ");#DecValTok("2");],
[#NormalTok("  ) ");#SpecialCharTok("+");],
[#NormalTok("  ");#CommentTok("# mean + SE at centre");],
[#NormalTok("  ");#FunctionTok("stat_summary");#NormalTok("(");],
[#NormalTok("    ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#FunctionTok("as.numeric");#NormalTok("(group)),");],
[#NormalTok("    ");#AttributeTok("fun.data =");#NormalTok(" mean_se,");],
[#NormalTok("    ");#AttributeTok("geom =");#NormalTok(" ");#StringTok("\"pointrange\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("colour =");#NormalTok(" ");#StringTok("\"black\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("size =");#NormalTok(" ");#FloatTok("0.6");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("linewidth =");#NormalTok(" ");#FloatTok("1.2");],
[#NormalTok("  ) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("stat_summary");#NormalTok("(");],
[#NormalTok("    ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#FunctionTok("as.numeric");#NormalTok("(group), ");#AttributeTok("group =");#NormalTok(" ");#DecValTok("1");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok("fun =");#NormalTok(" mean,");],
[#NormalTok("    ");#AttributeTok("geom =");#NormalTok(" ");#StringTok("\"line\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("linewidth =");#NormalTok(" ");#DecValTok("1");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("colour =");#NormalTok(" ");#StringTok("\"black\"");],
[#NormalTok("  ) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_x_continuous");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("breaks =");#NormalTok(" ");#DecValTok("1");#SpecialCharTok(":");#DecValTok("2");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("labels =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"control\"");#NormalTok(", ");#StringTok("\"embodied\"");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok("expand =");#NormalTok(" ");#FunctionTok("expansion");#NormalTok("(");#AttributeTok("add =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#FloatTok("0.3");#NormalTok(", ");#SpecialCharTok("-");#FloatTok("0.3");#NormalTok(")) ");#CommentTok("# more space left, less right");],
[#NormalTok("  ) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_fill_manual");#NormalTok("(");#AttributeTok("values =");#NormalTok(" group_colours, ");#AttributeTok("name =");#NormalTok(" ");#StringTok("\"group\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_colour_manual");#NormalTok("(");#AttributeTok("values =");#NormalTok(" group_colours, ");#AttributeTok("name =");#NormalTok(" ");#StringTok("\"group\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("title =");#NormalTok(" ");#StringTok("\"Score by group\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("x =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Score\"");],
[#NormalTok("  ) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("axis.text.x =");#NormalTok(" ");#FunctionTok("element_blank");#NormalTok("()");],
[#NormalTok("  )");],
[],
[#FunctionTok("print");#NormalTok("(p1)");],));
#box(image("03-wrangle_files/figure-typst/create-plots-1.svg"))

== Save out the data for modelling
<save-out-the-data-for-modelling>
#block[
#Skylighting(([#FunctionTok("write_csv");#NormalTok("(dat, ");#StringTok("\"data/dat.csv\"");#NormalTok(")");],));
]
= Modelling
<sec-modelling>
This chapter fits a Bayesian multi-level regression model to the data using #link("https://paulbuerkner.com/brms/")[#NormalTok("brms");] @burknerBrmsPackageBayesian2017 and #link("https://mc-stan.org/docs/cmdstan-guide/")[#NormalTok("CmdStan");]. The general approach largely follows Richard McElreath's textbook @mcelreathStatisticalRethinkingBayesian2020 and adopts a maximal varying effects structure @barrRandomEffectsStructure2013. #NormalTok("brms"); is handy for many reasons, one of which being that it uses the same formula syntax as #NormalTok("lme4");, which many people in psychology are already familiar with.

And for a helpful introduction to estimation approaches to regression, which I generally follow, I recommend reading this paper by Krushcke & Liddell @kruschkeBayesianNewStatistics2018. Figure 1 from #cite(<kruschkeBayesianNewStatistics2018>, form: "prose") is especially informative, as it nicely compares and contrasts how estimation approaches to data analysis compare to other approaches (#ref(<fig-kruschke>, supplement: [Figure])).

#figure([
#box(image("img/kruschke_fig1.png", alt: "Comparison of estimation, hypothesis testing, and other approaches to data analysis."))
], caption: figure.caption(
position: bottom, 
[
Adapted from Figure 1 in #cite(<kruschkeBayesianNewStatistics2018>, form: "prose").
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-kruschke>


== Read in the data
<read-in-the-data-1>
#block[
#Skylighting(([#NormalTok("dat ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");],
[#NormalTok("  ");#StringTok("\"data/dat.csv\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("show_col_types =");#NormalTok(" ");#ConstantTok("FALSE");],
[#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("group =");#NormalTok(" ");#FunctionTok("factor");#NormalTok("(");],
[#NormalTok("      group,");],
[#NormalTok("      ");#AttributeTok("levels =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"control\"");#NormalTok(", ");#StringTok("\"embodied\"");#NormalTok(")");],
[#NormalTok("    )");],
[#NormalTok("  )");],
[#FunctionTok("head");#NormalTok("(dat)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 5");],
[#NormalTok("  pid   item_id group   pre_score_z correct");],
[#NormalTok("  <chr>   <dbl> <fct>         <dbl>   <dbl>");],
[#NormalTok("1 P001       22 control       0.361       1");],
[#NormalTok("2 P001       23 control       0.361       1");],
[#NormalTok("3 P001       28 control       0.361       0");],
[#NormalTok("4 P001       17 control       0.361       1");],
[#NormalTok("5 P001        1 control       0.361       0");],
[#NormalTok("6 P001       26 control       0.361       1");],));
]
#Skylighting(([#CommentTok("# glimpse(dat)");],
[#CommentTok("# summary(dat)");],));
]
== Plot and check
<plot-and-check>
This just feels like good practice to take a look at the data again.

#Skylighting(([#NormalTok("dat_summary ");#OtherTok("<-");#NormalTok(" dat ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("filter");#NormalTok("(");#SpecialCharTok("!");#FunctionTok("is.na");#NormalTok("(correct)) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("summarise");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("score =");#NormalTok(" ");#FunctionTok("sum");#NormalTok("(correct),");],
[#NormalTok("    ");#AttributeTok("n_items =");#NormalTok(" ");#FunctionTok("n");#NormalTok("(),");],
[#NormalTok("    ");#AttributeTok(".by =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(pid, group)");],
[#NormalTok("  ) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("arrange");#NormalTok("(pid, group)");],
[],
[#CommentTok("# head(dat_summary)");],
[#CommentTok("# glimpse(dat_summary)");],
[],
[#NormalTok("group_colours ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#AttributeTok("control =");#NormalTok(" ");#StringTok("\"#4477AA\"");#NormalTok(", ");#AttributeTok("embodied =");#NormalTok(" ");#StringTok("\"#228833\"");#NormalTok(")");],
[],
[#NormalTok("p1 ");#OtherTok("<-");#NormalTok(" dat_summary ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("ggplot");#NormalTok("(");#FunctionTok("aes");#NormalTok("(");#AttributeTok("y =");#NormalTok(" score, ");#AttributeTok("fill =");#NormalTok(" group, ");#AttributeTok("colour =");#NormalTok(" group)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#CommentTok("# histogram slab nudged right");],
[#NormalTok("  ");#FunctionTok("stat_slab");#NormalTok("(");],
[#NormalTok("    ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#FunctionTok("as.numeric");#NormalTok("(group) ");#SpecialCharTok("+");#NormalTok(" ");#FloatTok("0.05");#NormalTok(", ");#AttributeTok("thickness =");#NormalTok(" ");#FunctionTok("after_stat");#NormalTok("(pdf)),");],
[#NormalTok("    ");#AttributeTok("side =");#NormalTok(" ");#StringTok("\"right\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("scale =");#NormalTok(" ");#FloatTok("0.4");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.5");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("density =");#NormalTok(" ");#StringTok("\"histogram\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("breaks =");#NormalTok(" ");#FunctionTok("breaks_fixed");#NormalTok("(");#AttributeTok("width =");#NormalTok(" ");#DecValTok("1");#NormalTok(")");],
[#NormalTok("  ) ");#SpecialCharTok("+");],
[#NormalTok("  ");#CommentTok("# dots nudged left with jitter");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("(");],
[#NormalTok("    ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#FunctionTok("as.numeric");#NormalTok("(group) ");#SpecialCharTok("-");#NormalTok(" ");#FloatTok("0.15");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok("position =");#NormalTok(" ");#FunctionTok("position_jitter");#NormalTok("(");#AttributeTok("width =");#NormalTok(" ");#FloatTok("0.1");#NormalTok(", ");#AttributeTok("height =");#NormalTok(" ");#DecValTok("0");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.4");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("size =");#NormalTok(" ");#DecValTok("2");],
[#NormalTok("  ) ");#SpecialCharTok("+");],
[#NormalTok("  ");#CommentTok("# mean + SE at centre");],
[#NormalTok("  ");#FunctionTok("stat_summary");#NormalTok("(");],
[#NormalTok("    ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#FunctionTok("as.numeric");#NormalTok("(group)),");],
[#NormalTok("    ");#AttributeTok("fun.data =");#NormalTok(" mean_se,");],
[#NormalTok("    ");#AttributeTok("geom =");#NormalTok(" ");#StringTok("\"pointrange\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("colour =");#NormalTok(" ");#StringTok("\"black\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("size =");#NormalTok(" ");#FloatTok("0.6");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("linewidth =");#NormalTok(" ");#FloatTok("1.2");],
[#NormalTok("  ) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("stat_summary");#NormalTok("(");],
[#NormalTok("    ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#FunctionTok("as.numeric");#NormalTok("(group), ");#AttributeTok("group =");#NormalTok(" ");#DecValTok("1");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok("fun =");#NormalTok(" mean,");],
[#NormalTok("    ");#AttributeTok("geom =");#NormalTok(" ");#StringTok("\"line\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("linewidth =");#NormalTok(" ");#DecValTok("1");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("colour =");#NormalTok(" ");#StringTok("\"black\"");],
[#NormalTok("  ) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_x_continuous");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("breaks =");#NormalTok(" ");#DecValTok("1");#SpecialCharTok(":");#DecValTok("2");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("labels =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"control\"");#NormalTok(", ");#StringTok("\"embodied\"");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok("expand =");#NormalTok(" ");#FunctionTok("expansion");#NormalTok("(");#AttributeTok("add =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#FloatTok("0.3");#NormalTok(", ");#SpecialCharTok("-");#FloatTok("0.3");#NormalTok(")) ");#CommentTok("# more space left, less right");],
[#NormalTok("  ) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_fill_manual");#NormalTok("(");#AttributeTok("values =");#NormalTok(" group_colours, ");#AttributeTok("name =");#NormalTok(" ");#StringTok("\"group\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_colour_manual");#NormalTok("(");#AttributeTok("values =");#NormalTok(" group_colours, ");#AttributeTok("name =");#NormalTok(" ");#StringTok("\"group\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("title =");#NormalTok(" ");#StringTok("\"Score by group\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("x =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Score\"");],
[#NormalTok("  ) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("axis.text.x =");#NormalTok(" ");#FunctionTok("element_blank");#NormalTok("()");],
[#NormalTok("  )");],
[],
[#FunctionTok("print");#NormalTok("(p1)");],));
#box(image("04-model_files/figure-typst/summarise-and-plot-1.svg"))

== Fit a model
<fit-a-model-1>
Fit a "maximal" model as specified by the design.

Maximal varying effects (varying effects are "random" effects in frequentist language) model that is specified by the design. See this paper by Barr et al., (2013) for a clear justification of taking the "maximal" approach: #link("https://www.sciencedirect.com/science/article/abs/pii/S0749596X12001180")

To help develop understanding, I will build up to the maximal model here by showing the formulas for two other models first.

+ A single level model formula.

#Skylighting(([#NormalTok("formula <- bf(correct ~ group + pre_score_z)");],));
#block[
#set enum(numbering: "1.", start: 2)
+ Add varying intercepts by pid.
]

#Skylighting(([#NormalTok("formula <- bf(correct ~ group + pre_score_z +");],
[#NormalTok("    (1 | pid))");],));
#block[
#set enum(numbering: "1.", start: 3)
+ Add varying intercepts and slopes by item\_id.
]

#Skylighting(([#NormalTok("formula <- bf(correct ~ group + pre_score_z +");],
[#NormalTok("    (1 | pid),");],
[#NormalTok("    (1 + group | item_id))");],));
But in the below, we will only fit one model, using formula 3.

#block[
#Skylighting(([#DocumentationTok("## formula");],
[#NormalTok("formula ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("bf");#NormalTok("(");],
[#NormalTok("  correct ");#SpecialCharTok("~");],
[#NormalTok("    group ");#SpecialCharTok("+");],
[#NormalTok("    pre_score_z ");#SpecialCharTok("+");],
[#NormalTok("    (");#DecValTok("1");#NormalTok(" ");#SpecialCharTok("|");#NormalTok(" pid) ");#SpecialCharTok("+");],
[#NormalTok("    (");#DecValTok("1");#NormalTok(" ");#SpecialCharTok("+");#NormalTok(" group ");#SpecialCharTok("|");#NormalTok(" item_id)");],
[#NormalTok(")");],
[],
[#DocumentationTok("## priors");],
[#FunctionTok("get_prior");#NormalTok("(formula, ");#AttributeTok("data =");#NormalTok(" dat, ");#AttributeTok("family =");#NormalTok(" ");#FunctionTok("bernoulli");#NormalTok("())");],
[],
[#DocumentationTok("## priors");],
[#NormalTok("priors ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");],
[#NormalTok("  ");#FunctionTok("prior");#NormalTok("(");#FunctionTok("normal");#NormalTok("(");#DecValTok("0");#NormalTok(", ");#DecValTok("2");#NormalTok("), ");#AttributeTok("class =");#NormalTok(" Intercept),");],
[#NormalTok("  ");#FunctionTok("prior");#NormalTok("(");#FunctionTok("normal");#NormalTok("(");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok("), ");#AttributeTok("class =");#NormalTok(" b),");],
[#NormalTok("  ");#FunctionTok("prior");#NormalTok("(");#FunctionTok("exponential");#NormalTok("(");#DecValTok("1");#NormalTok("), ");#AttributeTok("class =");#NormalTok(" sd),");],
[#NormalTok("  ");#FunctionTok("prior");#NormalTok("(");#FunctionTok("lkj");#NormalTok("(");#DecValTok("2");#NormalTok("), ");#AttributeTok("class =");#NormalTok(" cor)");],
[#NormalTok(")");],
[],
[#NormalTok("fit_b2 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("brm");#NormalTok("(");],
[#NormalTok("  ");#AttributeTok("formula =");#NormalTok(" formula,");],
[#NormalTok("  ");#AttributeTok("data =");#NormalTok(" dat,");],
[#NormalTok("  ");#AttributeTok("family =");#NormalTok(" ");#FunctionTok("bernoulli");#NormalTok("(),");],
[#NormalTok("  ");#AttributeTok("prior =");#NormalTok(" priors,");],
[#NormalTok("  ");#AttributeTok("chains =");#NormalTok(" ");#DecValTok("4");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("cores =");#NormalTok(" ");#DecValTok("24");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("iter =");#NormalTok(" ");#DecValTok("4000");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("warmup =");#NormalTok(" ");#DecValTok("2000");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("seed =");#NormalTok(" ");#DecValTok("123");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("save_pars =");#NormalTok(" ");#FunctionTok("save_pars");#NormalTok("(");#AttributeTok("all =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok("),");],
[#NormalTok("  ");#AttributeTok("file =");#NormalTok(" ");#StringTok("\"models/fit_b2\"");],
[#NormalTok(")");],));
]
#Skylighting(([#CommentTok("# read in the model");],
[#NormalTok("fit_b2 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("readRDS");#NormalTok("(");#StringTok("\"models/fit_b2.rds\"");#NormalTok(")");],
[#CommentTok("# Summary");],
[#FunctionTok("summary");#NormalTok("(fit_b2)");],));
#block[
#Skylighting(([#NormalTok("Loading required namespace: rstan");],));
]
#block[
#Skylighting(([#NormalTok(" Family: bernoulli ");],
[#NormalTok("  Links: mu = logit ");],
[#NormalTok("Formula: correct ~ group + pre_score_z + (1 | pid) + (1 + group | item_id) ");],
[#NormalTok("   Data: dat (Number of observations: 864) ");],
[#NormalTok("  Draws: 4 chains, each with iter = 4000; warmup = 2000; thin = 1;");],
[#NormalTok("         total post-warmup draws = 8000");],
[],
[#NormalTok("Multilevel Hyperparameters:");],
[#NormalTok("~item_id (Number of levels: 8) ");],
[#NormalTok("                             Estimate Est.Error l-95% CI u-95% CI Rhat Bulk_ESS");],
[#NormalTok("sd(Intercept)                    1.26      0.38     0.73     2.17 1.00     3077");],
[#NormalTok("sd(groupembodied)                0.19      0.16     0.01     0.58 1.00     6573");],
[#NormalTok("cor(Intercept,groupembodied)    -0.12      0.44    -0.86     0.74 1.00    13550");],
[#NormalTok("                             Tail_ESS");],
[#NormalTok("sd(Intercept)                    4576");],
[#NormalTok("sd(groupembodied)                4954");],
[#NormalTok("cor(Intercept,groupembodied)     6384");],
[],
[#NormalTok("~pid (Number of levels: 108) ");],
[#NormalTok("              Estimate Est.Error l-95% CI u-95% CI Rhat Bulk_ESS Tail_ESS");],
[#NormalTok("sd(Intercept)     1.04      0.15     0.76     1.34 1.00     3713     5535");],
[],
[#NormalTok("Regression Coefficients:");],
[#NormalTok("              Estimate Est.Error l-95% CI u-95% CI Rhat Bulk_ESS Tail_ESS");],
[#NormalTok("Intercept        -0.16      0.48    -1.13     0.78 1.00     2297     3384");],
[#NormalTok("groupembodied     0.16      0.26    -0.37     0.67 1.00     5834     5995");],
[#NormalTok("pre_score_z       0.31      0.13     0.06     0.56 1.00     5733     6060");],
[],
[#NormalTok("Draws were sampled using sample(hmc). For each parameter, Bulk_ESS");],
[#NormalTok("and Tail_ESS are effective sample size measures, and Rhat is the potential");],
[#NormalTok("scale reduction factor on split chains (at convergence, Rhat = 1).");],));
]
#Skylighting(([#CommentTok("# Diagnotics");],
[#FunctionTok("pp_check");#NormalTok("(fit_b2, ");#AttributeTok("ndraws =");#NormalTok(" ");#DecValTok("100");#NormalTok(", ");#AttributeTok("type =");#NormalTok(" ");#StringTok("\"bars_grouped\"");#NormalTok(", ");#AttributeTok("group =");#NormalTok(" ");#StringTok("\"group\"");#NormalTok(")");],));
#box(image("04-model_files/figure-typst/summary-model-b2-1.svg"))

At this point, you would run various model checks such as plotting chain convergence and other model checking metrics. These are skipped for now, given that this is a simple test workflow. But the basic idea would be that you wouldn't go to the next step of inference if the model had not been built in a satisfactory manner.

= Inference
<sec-inference>
This chapter uses posterior predictions to make inferences and evaluate hypotheses.

For more details on this kind of workflow for making inferences, I would suggest reading the following:

- #link("https://xcelab.net/rm/")[Statistical rethinking] by Richard McElreath @mcelreathStatisticalRethinkingBayesian2020. This provides a nice overview of prediction in the context of Bayesian data analysis.
- #link("https://marginaleffects.com/")[Model to meaning] by Vincent Arel-Bundock @arel-bundockModelMeaningHow2025, as well as these related journal articles @arel-bundockHowInterpretStatistical2024@rohrerModelsPredictionMachines2026. These articles provide the intuition and the tools to make it clear why it can often be advantageous to take a model and make predictions in a natural scale that that data were recorded in, rather than parameters in a regression model.

== Read in the data and models
<read-in-the-data-and-models-1>
#block[
#Skylighting(([#NormalTok("dat ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");],
[#NormalTok("  ");#StringTok("\"data/dat.csv\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("show_col_types =");#NormalTok(" ");#ConstantTok("FALSE");],
[#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("group =");#NormalTok(" ");#FunctionTok("factor");#NormalTok("(");],
[#NormalTok("      group,");],
[#NormalTok("      ");#AttributeTok("levels =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"control\"");#NormalTok(", ");#StringTok("\"embodied\"");#NormalTok(")");],
[#NormalTok("    )");],
[#NormalTok("  )");],
[#FunctionTok("head");#NormalTok("(dat)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 5");],
[#NormalTok("  pid   item_id group   pre_score_z correct");],
[#NormalTok("  <chr>   <dbl> <fct>         <dbl>   <dbl>");],
[#NormalTok("1 P001       22 control       0.361       1");],
[#NormalTok("2 P001       23 control       0.361       1");],
[#NormalTok("3 P001       28 control       0.361       0");],
[#NormalTok("4 P001       17 control       0.361       1");],
[#NormalTok("5 P001        1 control       0.361       0");],
[#NormalTok("6 P001       26 control       0.361       1");],));
]
#Skylighting(([#CommentTok("# glimpse(dat)");],
[#CommentTok("# summary(dat)");],));
]
read models, if already computed

#block[
#Skylighting(([#NormalTok("fit_b2 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("readRDS");#NormalTok("(");#StringTok("\"models/fit_b2.rds\"");#NormalTok(")");],
[#FunctionTok("summary");#NormalTok("(fit_b2)");],));
#block[
#Skylighting(([#NormalTok("Loading required namespace: rstan");],));
]
#block[
#Skylighting(([#NormalTok(" Family: bernoulli ");],
[#NormalTok("  Links: mu = logit ");],
[#NormalTok("Formula: correct ~ group + pre_score_z + (1 | pid) + (1 + group | item_id) ");],
[#NormalTok("   Data: dat (Number of observations: 864) ");],
[#NormalTok("  Draws: 4 chains, each with iter = 4000; warmup = 2000; thin = 1;");],
[#NormalTok("         total post-warmup draws = 8000");],
[],
[#NormalTok("Multilevel Hyperparameters:");],
[#NormalTok("~item_id (Number of levels: 8) ");],
[#NormalTok("                             Estimate Est.Error l-95% CI u-95% CI Rhat Bulk_ESS");],
[#NormalTok("sd(Intercept)                    1.26      0.38     0.73     2.17 1.00     3077");],
[#NormalTok("sd(groupembodied)                0.19      0.16     0.01     0.58 1.00     6573");],
[#NormalTok("cor(Intercept,groupembodied)    -0.12      0.44    -0.86     0.74 1.00    13550");],
[#NormalTok("                             Tail_ESS");],
[#NormalTok("sd(Intercept)                    4576");],
[#NormalTok("sd(groupembodied)                4954");],
[#NormalTok("cor(Intercept,groupembodied)     6384");],
[],
[#NormalTok("~pid (Number of levels: 108) ");],
[#NormalTok("              Estimate Est.Error l-95% CI u-95% CI Rhat Bulk_ESS Tail_ESS");],
[#NormalTok("sd(Intercept)     1.04      0.15     0.76     1.34 1.00     3713     5535");],
[],
[#NormalTok("Regression Coefficients:");],
[#NormalTok("              Estimate Est.Error l-95% CI u-95% CI Rhat Bulk_ESS Tail_ESS");],
[#NormalTok("Intercept        -0.16      0.48    -1.13     0.78 1.00     2297     3384");],
[#NormalTok("groupembodied     0.16      0.26    -0.37     0.67 1.00     5834     5995");],
[#NormalTok("pre_score_z       0.31      0.13     0.06     0.56 1.00     5733     6060");],
[],
[#NormalTok("Draws were sampled using sample(hmc). For each parameter, Bulk_ESS");],
[#NormalTok("and Tail_ESS are effective sample size measures, and Rhat is the potential");],
[#NormalTok("scale reduction factor on split chains (at convergence, Rhat = 1).");],));
]
]
== Calculate posterior predictions
<calculate-posterior-predictions>
Here we try a simple version, which is the population-average probability for a hypothetical average participant on a hypothetical average item.

#Skylighting(([#CommentTok("# create a dataframe to make predictions on");],
[#CommentTok("# two groups, avg pre-test score");],
[#NormalTok("nd ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("tibble");#NormalTok("(");],
[#NormalTok("  ");#AttributeTok("group =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"control\"");#NormalTok(", ");#StringTok("\"embodied\"");#NormalTok("),");],
[#NormalTok("  ");#AttributeTok("pre_score_z =");#NormalTok(" ");#DecValTok("0");],
[#NormalTok(")");],
[],
[#CommentTok("# all draws per group");],
[#NormalTok("epred ");#OtherTok("<-");#NormalTok(" fit_b2 ");#SpecialCharTok("|>");],
[#NormalTok("  tidybayes");#SpecialCharTok("::");#FunctionTok("add_epred_draws");#NormalTok("(");#AttributeTok("newdata =");#NormalTok(" nd, ");#AttributeTok("re_formula =");#NormalTok(" ");#ConstantTok("NA");#NormalTok(")");],
[],
[#CommentTok("# difference (all draws)");],
[#NormalTok("epred_diff ");#OtherTok("<-");#NormalTok(" epred ");#SpecialCharTok("|>");],
[#NormalTok("  tidybayes");#SpecialCharTok("::");#FunctionTok("compare_levels");#NormalTok("(.epred, ");#AttributeTok("by =");#NormalTok(" group)");],
[],
[#CommentTok("# plot group epreds");],
[#NormalTok("plot_epred ");#OtherTok("<-");#NormalTok(" epred ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("ggplot");#NormalTok("(");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" .epred, ");#AttributeTok("y =");#NormalTok(" group, ");#AttributeTok("fill =");#NormalTok(" group)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("stat_halfeye");#NormalTok("(");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.7");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"P(correct)\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(")");],
[],
[#CommentTok("# plot the difference");],
[#NormalTok("plot_diff ");#OtherTok("<-");#NormalTok(" epred_diff ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("ggplot");#NormalTok("(");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" .epred)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("stat_halfeye");#NormalTok("(");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.7");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_vline");#NormalTok("(");#AttributeTok("xintercept =");#NormalTok(" ");#DecValTok("0");#NormalTok(", ");#AttributeTok("linetype =");#NormalTok(" ");#StringTok("\"dashed\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Δ P(correct) [embodied - control]\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(")");],
[],
[#NormalTok("p1 ");#OtherTok("<-");#NormalTok(" plot_epred ");#SpecialCharTok("|");#NormalTok(" plot_diff");],
[#NormalTok("p1");],));
#box(image("05-effects_files/figure-typst/calc-posterior-preds-1.svg"))

#Skylighting(([#CommentTok("# summarise if needed");],
[#NormalTok("epred ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("median_qi");#NormalTok("(.epred, ");#AttributeTok(".width =");#NormalTok(" ");#FloatTok("0.95");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 2 × 9");],
[#NormalTok("  group    pre_score_z  .row .epred .lower .upper .width .point .interval");],
[#NormalTok("  <chr>          <dbl> <int>  <dbl>  <dbl>  <dbl>  <dbl> <chr>  <chr>    ");],
[#NormalTok("1 control            0     1  0.460  0.245  0.686   0.95 median qi       ");],
[#NormalTok("2 embodied           0     2  0.497  0.275  0.717   0.95 median qi       ");],));
]
#Skylighting(([#NormalTok("epred_diff ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("median_qi");#NormalTok("(.epred, ");#AttributeTok(".width =");#NormalTok(" ");#FloatTok("0.95");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 8");],
[#NormalTok("  group              pre_score_z .epred  .lower .upper .width .point .interval");],
[#NormalTok("  <chr>                    <dbl>  <dbl>   <dbl>  <dbl>  <dbl> <chr>  <chr>    ");],
[#NormalTok("1 embodied - control           0 0.0372 -0.0894  0.157   0.95 median qi       ");],));
]
#show: appendices.with("Appendices", hide-parent: true)
#heading(level: 1, numbering: none)[Appendices]
#heading(level: 1, numbering: none)[Data dictionary]
<sec-data-dictionary>
This appendix documents all datasets in the #NormalTok("data/"); folder. These files are pre-compiled and used throughout the book to avoid requiring model refits or long-running simulations during rendering.

#heading(level: 2, numbering: none)[sim\_dat.csv]
<sec-dict-sim-dat>
The primary simulated dataset used in #ref(<sec-planning>, supplement: [Chapter]) and #ref(<sec-data-processing>, supplement: [Chapter]). It is synthetic, generated to match the structure of previously collected data in the lab. It is not real data.

#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([Variable], [Type], [Values], [Description],),
  table.hline(),
  [#NormalTok("pid");], [character], [P001--P216], [Participant identifier],
  [#NormalTok("item_id");], [integer], [1--32], [Item identifier],
  [#NormalTok("group");], [factor], [control, embodied], [Experimental condition (between-person)],
  [#NormalTok("test_time");], [factor], [pre, post, delay], [Testing occasion],
  [#NormalTok("correct");], [integer], [0, 1], [Binary accuracy on each trial],
  [#NormalTok("pre_score_z");], [double], [continuous], [Standardised pre-test score],
)
#heading(level: 2, numbering: none)[sim\_dat\_wide.csv]
<sec-dict-sim-dat-wide>
A wide-format version of #NormalTok("sim_dat.csv");, used in #ref(<sec-data-processing>, supplement: [Chapter]) as a toy example for demonstrating #NormalTok("pivot_longer()");. Each row is one participant × test time combination, with one column per item.

#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([Variable], [Type], [Values], [Description],),
  table.hline(),
  [#NormalTok("pid");], [character], [P001--P216], [Participant identifier],
  [#NormalTok("group");], [factor], [control, embodied], [Experimental condition (between-person)],
  [#NormalTok("test_time");], [factor], [pre, post, delay], [Testing occasion],
  [#NormalTok("pre_score_z");], [double], [continuous], [Standardised pre-test score],
  [#NormalTok("item_1"); … #NormalTok("item_32");], [integer], [0, 1], [Binary accuracy, one column per item],
)
#heading(level: 2, numbering: none)[dat.csv]
<sec-dict-dat>
A simplified version of #NormalTok("sim_dat.csv"); used in #ref(<sec-modelling>, supplement: [Chapter]) and #ref(<sec-inference>, supplement: [Chapter]). It retains only the post-test observations and drops variables not needed for the modelling chapters, giving a cleaner starting point for readers focused on model fitting rather than data processing.

#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([Variable], [Type], [Values], [Description],),
  table.hline(),
  [#NormalTok("pid");], [character], [P001--P216], [Participant identifier],
  [#NormalTok("item_id");], [integer], [1--32], [Item identifier],
  [#NormalTok("group");], [factor], [control, embodied], [Experimental condition (between-person)],
  [#NormalTok("correct");], [integer], [0, 1], [Binary accuracy on each trial],
  [#NormalTok("pre_score_z");], [double], [continuous], [Standardised pre-test score],
)
#heading(level: 2, numbering: none)[p\_100\_sims.csv]
<sec-dict-p-100-sims>
The output of the simulation study in #ref(<sec-planning>, supplement: [Chapter]) (section 6.6). Each row is one parameter estimate from one fitted model across the simulation grid. This file is read in by the plotting and precision chunks, which render without needing to rerun the simulations.

#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([Variable], [Type], [Values], [Description],),
  table.hline(),
  [#NormalTok("rep");], [integer], [1--100], [Simulation replicate index],
  [#NormalTok("subj_n");], [integer], [100, 150, 200], [Number of subjects in that simulation],
  [#NormalTok("b1");], [double], [0.15, 0.40, 0.87, 1.39], [True group effect (log-odds) used in data-generating process],
  [#NormalTok("parameter");], [character], [Intercept, groupembodied, pre\_score\_z], [Model parameter name],
  [#NormalTok("Estimate");], [double], [continuous], [Posterior median for that parameter],
  [#NormalTok("Est.Error");], [double], [continuous], [Posterior SD],
  [#NormalTok("Q2.5");], [double], [continuous], [2.5th percentile of posterior (lower 95% CI)],
  [#NormalTok("Q97.5");], [double], [continuous], [97.5th percentile of posterior (upper 95% CI)],
)
#heading(level: 2, numbering: none)[Models]
<models>
Pre-fitted model objects are stored in #NormalTok("models/"); as #NormalTok(".rds"); files. All were fit with brms using CmdStan on the backend.

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([File], [Description], [Chapter],),
  table.hline(),
  [#NormalTok("fit_b1.rds");], [Bernoulli multilevel model fit to #NormalTok("sim_dat.csv"); (post-test only)], [#ref(<sec-planning>, supplement: [Chapter])],
  [#NormalTok("sim_b1.rds");], [Same formula as #NormalTok("fit_b1");, fit to a single simulated dataset (#NormalTok("d1");) to validate the data-generating process], [#ref(<sec-planning>, supplement: [Chapter])],
  [#NormalTok("fit_b2.rds");], [Bernoulli multilevel model fit to #NormalTok("dat.csv");, the wrangled dataset used in the modelling and effects chapters], [#ref(<sec-modelling>, supplement: [Chapter])],
)



#set bibliography(style: "apa.csl")

#bibliography(("references.bib"))

