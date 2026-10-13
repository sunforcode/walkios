import XCTest
@testable import Walk

final class RouteArtworkSourceTests: XCTestCase {
    func testYadingSceneReferencesResolveToOnlyTheSixBundledAssets() {
        let names = ["YadingSceneOverview"] + (1...5).map { "YadingSceneDay\($0)" }
        for name in names {
            XCTAssertEqual(RouteArtworkSource.resolve("asset://\(name)"), .bundledAsset(name))
        }
    }

    func testUnknownAndDecoratedAssetReferencesRemainUnavailable() {
        let references = [
            "YadingSceneOverview", "asset://Unknown", "asset://YadingSceneDay6",
            "asset://YadingSceneOverview/", "asset://YadingSceneOverview?variant=1",
            "asset://YadingSceneOverview#detail", "asset://../YadingSceneOverview",
            "asset://%59adingSceneOverview", "asset://yadingsceneoverview",
            "file:///tmp/YadingSceneOverview.png", "data:image/png;base64,AAAA",
        ]
        for reference in references {
            XCTAssertNil(RouteArtworkSource.resolve(reference), reference)
        }
    }

    func testHTTPArtworkKeepsItsURLIncludingSignedQueryParameters() throws {
        for reference in [
            "https://images.example.com/route.png?token=a%2Fb&size=large",
            "http://images.example.com/route.jpg",
        ] {
            let url = try XCTUnwrap(URL(string: reference))
            XCTAssertEqual(RouteArtworkSource.resolve(reference), .remoteURL(url))
        }
    }

    func testMissingOrNonabsoluteReferencesDoNotBecomeNetworkRequests() {
        for reference in [nil, "", " \n ", "/route.png", "images/route.png", "https:///route.png", "https://"] {
            XCTAssertNil(RouteArtworkSource.resolve(reference))
        }
        XCTAssertEqual(
            RouteArtworkSource.resolve(" \nasset://YadingSceneOverview \n"),
            .bundledAsset("YadingSceneOverview")
        )
    }
}
