#if !os(macOS)
import Foundation
import Glibc

@main
enum HamsterInfestationMain {
    static func main() {
        fputs("Hamster Infestation is built on a Mac. Run scripts/build-app.sh there.\n", stderr)
        fputs("The app it produces is named Software-Debugger-4.2-hmst.app.\n", stderr)
        exit(1)
    }
}
#endif
