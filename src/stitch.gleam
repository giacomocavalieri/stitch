import gleam/list

// STITCHES --------------------------------------------------------------------

pub type Stitch {
  /// One or more knit stitches: `k1`, `knit`, `k2`.
  ///
  K(Int)

  /// Knit together 2 or more stitches: `k2tog`.
  ///
  KTog(Int)

  /// Slip, slip knit: `ssk`.
  ///
  SSK

  /// One or more purl stitches: `p1`, `purl`, `p2`.
  ///
  P(Int)

  /// Purl together 2 or more stitches: `p2tog`.
  ///
  PTog(Int)

  /// Yarn over: `yo`.
  ///
  YO

  /// Slip one, knit one pass over slipped knit: `skpo`.
  ///
  SKPO

  /// Repetition of groups of stitches: `(k1, p2)x3`, `(k1, yo) twice`.
  ///
  Group(repeat: Int, stitches: List(Stitch))
}

/// The number of stitches required to make a stitch.
/// For example a knit stitch will take a single stitch, while knitting three
/// stitches together will take three stitches.
///
fn taken(by stitch: Stitch) -> Int {
  case stitch {
    Group(times, stitches) -> times * all_taken(by: stitches)
    K(n) | KTog(n) | P(n) | PTog(n) -> n
    SSK | SKPO -> 2
    YO -> 0
  }
}

fn all_taken(by stitches: List(Stitch)) -> Int {
  list.fold(stitches, 0, fn(acc, stitch) { acc + taken(by: stitch) })
}

/// The number of stitches produced after making a stitch.
/// For example a knit stitch  will produce a single stitch, purling three
/// stitches together will still produce a single stitch.
///
fn produced(by stitch: Stitch) -> Int {
  case stitch {
    Group(times, stitches) -> times * all_produced(by: stitches)
    KTog(_) | PTog(_) | SSK | SKPO | YO -> 1
    K(n) | P(n) -> n
  }
}

fn all_produced(by stitches: List(Stitch)) -> Int {
  list.fold(stitches, 0, fn(acc, stitch) { acc + produced(stitch) })
}

// PATTERN ROWS AND REPETITIONS ------------------------------------------------

pub type Row {
  Row(start: List(Stitch), repetition: List(Stitch), end: List(Stitch))
}

pub type CastOn {
  CastOn(multiple: Int, rest: Int)
}

pub fn cast_on(from pattern: List(Row)) -> CastOn {
  use _acc, row <- list.fold_until(over: pattern, from: CastOn(1, 0))
  let Row(start: start, repetition: repetition, end: end) = row
  let rest = all_taken(by: start) + all_taken(by: end)
  case all_taken(by: repetition) {
    // If there's no repetition or it's not interesting as it takes just one
    // stitch we keep on looking for a more interesting repetition.
    // If, however, we get to the end of the pattern without having found
    // anything of interest we will default to this repetition.
    0 as n | 1 as n -> list.Continue(CastOn(n, rest))

    // As soon as we find an interesting repetition we bail out and use that as
    // an approximation of the number of stitches we need to cast on.
    // > ⚠️ This might not be the right call for some patterns but will be more
    // > than enough for most cases.
    n -> list.Stop(CastOn(n, rest))
  }
}

pub fn stitches_after_knitting(row row: Row, from initial_stitches: Int) -> Int {
  let Row(start, repetition, end) = row

  let produced_by_start = all_produced(by: start)
  let produced_by_end = all_produced(by: end)
  let stitches_for_repetition =
    initial_stitches - all_taken(by: start) - all_taken(by: end)

  let repeats = stitches_for_repetition / all_taken(by: repetition)
  let produced_by_repetition = all_produced(by: repetition) * repeats

  produced_by_start + produced_by_repetition + produced_by_end
}

// KNITTING --------------------------------------------------------------------

// pub opaque type State {
//   State(
//     stitches: Int,
//     repetition: Int,
//     current_row: Int,
//     current_stitch: Int,
//     pattern: List(Row),
//   )
// }
//
// pub fn advance_row(state: State) -> State {
//   let State(stitches, repetition, current_row, _current_stitch, pattern) = state
//   let assert Ok(row) = list.at(pattern, current_row - 1)
//   let new_stitches = stitches_after_knitting(row, from: stitches)
//   case int.compare(current_row, list.length(pattern)) {
//     Lt -> State(new_stitches, repetition, current_row + 1, 1, pattern)
//     Gt | Eq -> State(new_stitches, repetition + 1, 1, 1, pattern)
//   }
// }

//fn run(name: String, state: State, show_help: Bool, focus: Bool) -> Nil {
//  io.println("\u{001b}[2J\u{001b}[1;1H" <> name <> "\n")
//
//  case focus {
//    False -> io.println(pretty_state(state))
//    True -> io.println(pretty_focus_state(state))
//  }
//
//  case show_help && !focus {
//    False -> io.println(ansi.dim("\nPress ? to show help text"))
//    True -> {
//      io.println("")
//      io.println(ansi.dim("- ENTER to advance to next row"))
//      io.println(ansi.dim("- F     to toggle focus mode"))
//      io.println(ansi.dim("- ?     to show/hide this help text"))
//    }
//  }
//
//  case erlang.get_line("") {
//    Ok("?\n") -> run(name, state, !show_help, focus)
//    Ok("F\n") | Ok("f\n") -> run(name, state, False, !focus)
//    Ok("\n") | Ok(_) | Error(_) ->
//      run(name, advance_row(state), show_help, focus)
//  }
//}

// STRING VISUALISATION --------------------------------------------------------

// fn pretty_state(state: State) -> String {
//   let State(stitches, repetition, current_row, _, pattern) = state
//   let assert Ok(row) = list.at(pattern, current_row - 1)
//
//   let repetition = ansi.yellow(rank.ordinalise(repetition) <> " repeat")
//   let row_number = int.to_string(current_row)
//   let rows = int.to_string(list.length(pattern))
//   let row_counter = ansi.yellow(row_number <> " out of " <> rows <> ": ")
//   let pretty_row = ansi.italic(row_to_string(row))
//
//   let current_stitches = int.to_string(stitches)
//   let stitches_after =
//     int.to_string(stitches_after_knitting(row, from: stitches))
//
//   [
//     "You're on your " <> repetition <> " of the pattern.",
//     "Knitting row " <> row_counter,
//     "",
//     "  " <> row_number <> ": " <> pretty_row,
//     "",
//     "You should have " <> current_stitches <> " stitches on your iron.",
//     "After this row you should have " <> stitches_after <> ".",
//   ]
//   |> string.join(with: "\n")
// }
//
// fn pretty_focus_state(state: State) -> String {
//   let State(stitches, _, current_row, _, pattern) = state
//   let assert Ok(row) = list.at(pattern, current_row - 1)
//
//   let current = int.to_string(current_row)
//   let out_of = ansi.dim("/" <> int.to_string(list.length(pattern)) <> ":")
//   let pretty_row = ansi.italic(row_to_string(row))
//
//   let new_stitches = int.to_string(stitches_after_knitting(row, from: stitches))
//   [
//     "  " <> current <> out_of <> " " <> pretty_row,
//     "  " <> ansi.dim(int.to_string(stitches) <> " ► " <> new_stitches),
//   ]
//   |> string.join(with: "\n")
// }

// pub fn to_string(stitch: Stitch) -> String {
//   case stitch {
//     K(n) -> "k" <> int.to_string(n)
//     KTog(n) -> "k" <> int.to_string(n) <> "tog"
//     SSK -> "ssk"
//     P(n) -> "p" <> int.to_string(n)
//     PTog(n) -> "p" <> int.to_string(n) <> "tog"
//     YO -> "yo"
//     SKPO -> "skpo"
//     Group(repeat: n, stitches: stitches) ->
//       case int.compare(n, 1) {
//         Lt -> ""
//         Eq -> "(" <> stitches_to_string(stitches) <> ")"
//         Gt -> "(" <> stitches_to_string(stitches) <> ")x" <> int.to_string(n)
//       }
//   }
// }

// fn stitches_to_string(stitches: List(Stitch)) -> String {
//   list.map(stitches, to_string)
//   |> string.join(with: ", ")
// }

// fn row_to_string(row: Row) -> String {
//   let Row(start, repeat, end) = row
//   [
//     stitches_to_string(start),
//     "*" <> stitches_to_string(repeat) <> "*",
//     stitches_to_string(end),
//   ]
//   |> list.filter(keeping: fn(string) { string != "" })
//   |> string.join(with: ", ")
// }

// EXAMPLES --------------------------------------------------------------------

/// http://www.theweeklystitch.com/2016/08/grapevine-lace.html
pub fn grapevine_lace() -> List(Row) {
  // All odd rows are always the same
  let odd_row = Row([], [P(1)], [])
  let even_rows = [
    Row([K(2)], [KTog(2), K(1), YO, K(1), SSK, K(2)], [K(4)]),
    Row([K(1), KTog(2), K(1), YO], [K(1), YO, K(1), SSK, KTog(2), K(1), YO], [
      K(2),
    ]),
    Row([K(3), YO], [K(3), YO, K(1), SSK, K(1), YO], [K(3)]),
    Row([K(5)], [KTog(2), K(1), YO, K(1), SSK, K(2)], [K(2)]),
    Row([K(4)], [KTog(2), K(1), Group(2, [YO, K(1)]), SSK], [K(3)]),
    Row([K(3), KTog(2)], [K(1), YO, K(3), YO, K(1), KTog(2)], [K(2)]),
  ]

  [odd_row, ..list.intersperse(even_rows, odd_row)]
}

pub fn fishbone() -> List(Row) {
  [
    Row([K(1)], [K(1), YO, K(2), SKPO, KTog(2), K(2), YO], [K(1)]),
    Row([], [P(1)], []),
    Row([K(1)], [YO, K(2), SKPO, KTog(2), K(2), YO, K(1)], [K(1)]),
    Row([], [P(1)], []),
  ]
}

/// https://www.purlsoho.com/create/2008/12/02/easy-mistake-stitch-scarf/
pub fn mistake_stitch_scarf() -> List(Row) {
  [Row([], [K(2), P(2)], [K(2), P(1)])]
}
