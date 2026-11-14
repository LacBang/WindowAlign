import AppKit

@main
struct LayoutTests {
    static func main() {
        let area = CGRect(x: 100, y: 50, width: 1200, height: 900)
        let current = CGRect(x: 200, y: 200, width: 700, height: 600)
        assert(Layout.left.frame(in: area, current: current) == CGRect(x: 100, y: 50, width: 600, height: 900))
        assert(Layout.right.frame(in: area, current: current) == CGRect(x: 700, y: 50, width: 600, height: 900))
        assert(Layout.top.frame(in: area, current: current) == CGRect(x: 100, y: 500, width: 1200, height: 450))
        assert(Layout.bottomRight.frame(in: area, current: current) == CGRect(x: 700, y: 50, width: 600, height: 450))
        assert(Layout.middleThird.frame(in: area, current: current) == CGRect(x: 500, y: 50, width: 400, height: 900))
        assert(Layout.rightTwoThirds.frame(in: area, current: current) == CGRect(x: 500, y: 50, width: 800, height: 900))
        assert(Layout.center.frame(in: area, current: current) == CGRect(x: 350, y: 200, width: 700, height: 600))
        print("LayoutTests: 7 passed")
    }
}
