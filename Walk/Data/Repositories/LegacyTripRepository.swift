import Foundation

protocol TripRepository {
    func fetchTrips(
        keyword: String?,
        status: TripStatus?,
        organizerID: String?,
        participantID: String?,
        page: Int,
        size: Int,
        sort: [String]
    ) async throws -> Page<Trip>
    func fetchTrip(id: String) async throws -> Trip
    func createTrip(_ input: TripCreateRequestDTO) async throws -> Trip
    func updateTrip(id: String, input: TripUpdateRequestDTO) async throws -> Trip
    func deleteTrip(id: String) async throws
    func updateTripStatus(id: String, status: TripStatus) async throws -> Trip
}

extension TripRepository {
    func fetchTrips(
        keyword: String? = nil,
        status: TripStatus? = nil,
        organizerID: String? = nil,
        participantID: String? = nil,
        page: Int = 0,
        size: Int = 20,
        sort: [String] = []
    ) async throws -> Page<Trip> {
        try await fetchTrips(
            keyword: keyword,
            status: status,
            organizerID: organizerID,
            participantID: participantID,
            page: page,
            size: size,
            sort: sort
        )
    }
}

struct DefaultTripRepository: TripRepository {
    let client: any APIClient

    func fetchTrips(
        keyword: String?,
        status: TripStatus?,
        organizerID: String?,
        participantID: String?,
        page: Int,
        size: Int,
        sort: [String]
    ) async throws -> Page<Trip> {
        let dto = try await client.execute(TripAPI.List(
            keyword: keyword,
            status: status,
            organizerID: organizerID,
            participantID: participantID,
            page: page,
            size: size,
            sort: sort
        ))
        return dto.map(Trip.init(dto:))
    }

    func fetchTrip(id: String) async throws -> Trip {
        Trip(dto: try await client.execute(TripAPI.Detail(id: id)))
    }

    func createTrip(_ input: TripCreateRequestDTO) async throws -> Trip {
        Trip(dto: try await client.execute(TripAPI.Create(input: input)))
    }

    func updateTrip(id: String, input: TripUpdateRequestDTO) async throws -> Trip {
        Trip(dto: try await client.execute(TripAPI.Update(id: id, input: input)))
    }

    func deleteTrip(id: String) async throws {
        _ = try await client.execute(TripAPI.Delete(id: id))
    }

    func updateTripStatus(id: String, status: TripStatus) async throws -> Trip {
        Trip(dto: try await client.execute(TripAPI.UpdateStatus(id: id, status: status)))
    }
}
