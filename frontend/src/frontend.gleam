//// Build entry shim. `lustre/dev build` boots the module named after the
//// package (`frontend`), so this simply delegates to the real entry point.
//// Open `royal/app` to read the app's state and logic.

import royal/app

pub fn main() -> Nil {
  app.main()
}
