breed [ pages page ]
breed [ surfers surfer ]

pages-own [
  rank new-rank ; for the diffusion approach
  visits ; for the random-surfer approach
]

surfers-own [ current-page ]

globals [ total-rank max-rank ]

;;
;; Setup Procedures
;;

to setup
  clear-all
  set-default-shape pages "circle"

  ifelse network-choice = "Example 1"
  [ create-network-example-1 ][
    ifelse network-choice = "Example 2"
    [ create-network-example-2 ][
      ifelse network-choice = "Preferential Attachment"
      [ create-network-preferential 100 2 ]
      [ user-message word "Error: unknown network-choice: " network-choice ] ] ]

  ask patches [ set pcolor white ]
  ask pages
  [ set rank 1 / count pages ]
  update-globals
  ask pages
  [
    setxy random-xcor random-ycor
    set label-color black
    update-page-appearance
  ]

  repeat 300 [ do-layout ]

  ask links [ set shape "curved" ]
  reset-ticks
end

to create-network-example-1
  create-pages 11
  ask page 0 [ set color blue create-link-from page 3 ]
  ask page 1 [ set color red create-links-from (turtle-set page 2 page 3 page 4 page 5 page 6 page 7 page 8 ) ]
  ask page 2 [ set color orange create-link-from page 1 ]
  ask page 3 [ set color green create-link-from page 4 ]
  ask page 4 [ set color yellow create-links-from (turtle-set page 5 page 6 page 7 page 8 page 9 page 10) ]
  ask page 5 [ set color green create-link-from page 4 ]
  ask pages with [who > 5] [ set color violet ]
end

to create-network-example-2
  create-pages 8
  ask page 0 [ die ]
  ask page 1 [ create-links-from (turtle-set page 2 page 3 page 5 page 6) ]
  ask page 2 [ create-links-from (turtle-set page 1 page 3 page 4) ]
  ask page 3 [ create-links-from (turtle-set page 1 page 4 page 5) ]
  ask page 4 [ create-links-from (turtle-set page 1 page 5) ]
  ask page 5 [ create-links-from (turtle-set page 1 page 4 page 6 page 7) ]
  ask page 6 [ create-links-from (turtle-set page 5) ]
  ask page 7 [ create-links-from (turtle-set page 1) ]
end

to create-network-preferential [ n k ]
  create-pages n [ set color sky ]
  link-preferentially pages k
end

; The parameter k (always an integer) gives the number of edges to add at
; each step (e.g. k=1 builds a tree)
to link-preferentially [nodeset k]
  ;; get the nodes in sorted order
  let node-list sort nodeset

  ;; get a sublist of the nodes from 0 to k
  let neighbor-choice-list sublist node-list 0 k

  ;; ask the kth node...
  ask item k node-list
  [
    ;; to make a link either to or from each preceding
    ;; node in the sorted list.
    foreach neighbor-choice-list [ neighbor ->
      ifelse random 2 = 0
        [ create-link-to neighbor ]
        [ create-link-from neighbor ]
    ]
    ;; add k copies of this node to the beginning of the sublist
    set neighbor-choice-list sentence (n-values k [self]) neighbor-choice-list
  ]

  ;; ask each node after the kth node in order...
  foreach sublist node-list (k + 1) (length node-list) [ node ->
    ask node [
      ;; ...to make k links
      let temp-neighbor-list neighbor-choice-list
      repeat k
      [
        ;; link to one of the nodes in the neighbor list
        ;; we remove that node from the list once it's been linked to
        ;; however, there may be more than one copy of some nodes
        ;; since those nodes have a higher probability of being linked to
        let neighbor one-of temp-neighbor-list
        set temp-neighbor-list remove neighbor temp-neighbor-list
        ;; when we've linked to a node put another copy of it on the
        ;; master neighbor choice list as it's now more likely to be
        ;; linked to again
        set neighbor-choice-list fput neighbor neighbor-choice-list
        ifelse random 2 = 0
          [ create-link-to neighbor ]
          [ create-link-from neighbor ]
      ]
      set neighbor-choice-list sentence (n-values k [self]) neighbor-choice-list
    ]
  ]
end

to do-layout
  layout-spring pages links 0.2 20 / (sqrt count pages) 0.5
end

;;
;; Runtime Procedures
;;

to go
  ifelse calculation-method = "diffusion"
  [
    if any? surfers [ ask surfers [ die ] ] ;; remove surfers if the calculation-method is changed

    ;; return links and pages to initial state
    ask links [ set color gray set thickness 0 ]
    ask pages [ set new-rank 0 ]

    ask pages
    [
      ifelse any? out-link-neighbors
      [
        ;; if a node has any out-links divide current rank
        ;; equally among them.
        let rank-increment rank / count out-link-neighbors
        ask out-link-neighbors [
          set new-rank new-rank + rank-increment
        ]
      ]
      [
        ;; if a node has no out-links divide current
        ;; rank equally among all the nodes
        let rank-increment rank / count pages
        ask pages [
          set new-rank new-rank + rank-increment
        ]
      ]
    ]

    ask pages
    [
      ;; set current rank to the new-rank and take the damping-factor into account
      set rank (1 - damping-factor) / count pages + damping-factor * new-rank
    ]
  ]
  [ ;;; "random-surfer" calculation-method
    ; surfers are created or destroyed on the fly if users move the
    ; NUMBER-OF-SURFERS slider while the model is running.
    if count surfers < number-of-surfers
    [
      create-surfers number-of-surfers - count surfers
      [
        set current-page one-of pages
        ifelse watch-surfers?
        [ move-surfer ]
        [ hide-turtle ]
      ]
    ]
    if count surfers > number-of-surfers
    [
      ask n-of (count surfers - number-of-surfers) surfers
        [ die ]
    ]
    ;; return links to their initial state
    ask links [ set color gray set thickness 0 ]

    ask surfers [
      let old-page current-page
      ;; increment the visits on the page we're on
      ask current-page [ set visits visits + 1 ]
      ;; with a probability depending on the damping-factor either go to a
      ;; random page or a random one of the pages that this page is linked to
      ifelse random-float 1.0 <= damping-factor and any? [my-out-links] of current-page
      [ set current-page one-of [out-link-neighbors] of current-page ]
      [ set current-page one-of pages ]

      ;; update the visualization
      ifelse watch-surfers?
      [
        show-turtle
        move-surfer
        let surfer-color color
        ask old-page [
          let traveled-link out-link-to [current-page] of myself
          if traveled-link != nobody [
            ask traveled-link [ set color surfer-color set thickness 0.08 ]
          ]
        ]
      ]
      [ hide-turtle ]
    ]
    ;; update the rank of each page
    let total-visits sum [visits] of pages
    ask pages [
      set rank visits / total-visits
    ]
  ]

  update-globals
  ask pages [ update-page-appearance ]
  tick
end

to move-surfer ;; surfer procedure
  face current-page
  move-to current-page
end

to update-globals
  set total-rank sum [rank] of pages
  set max-rank max [rank] of pages
end

to update-page-appearance ;; page procedure
  ; keep size between 0.1 and 5.0
  set size 0.2 + 4 * sqrt (rank / total-rank)
  ifelse show-page-ranks?
  [ set label word (precision rank 3) "     " ]
  [ set label "" ]
end


; Copyright 2009 Uri Wilensky.
; See Info tab for full copyright and license.