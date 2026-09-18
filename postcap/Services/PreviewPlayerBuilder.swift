import AVFoundation

struct PreviewPlayerConfiguration {
    var player: AVPlayer
    var audioTrackIDs: [Int: CMPersistentTrackID]
}

enum PreviewPlayerBuilder {
    static func build(for url: URL) async throws -> PreviewPlayerConfiguration {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let sourceRange = CMTimeRange(start: .zero, duration: duration)
        let composition = AVMutableComposition()

        if let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first,
           let compositionVideoTrack = composition.addMutableTrack(
               withMediaType: .video,
               preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            let trackRange = try await sourceVideoTrack.load(.timeRange)
            let insertionRange = CMTimeRangeGetIntersection(sourceRange, otherRange: trackRange)
            try compositionVideoTrack.insertTimeRange(insertionRange, of: sourceVideoTrack, at: insertionRange.start)
            compositionVideoTrack.preferredTransform = try await sourceVideoTrack.load(.preferredTransform)
        }

        var audioTrackIDs: [Int: CMPersistentTrackID] = [:]
        let sourceAudioTracks = try await asset.loadTracks(withMediaType: .audio)

        for (index, sourceAudioTrack) in sourceAudioTracks.enumerated() {
            guard let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else { continue }

            let trackRange = try await sourceAudioTrack.load(.timeRange)
            let insertionRange = CMTimeRangeGetIntersection(sourceRange, otherRange: trackRange)
            try compositionAudioTrack.insertTimeRange(insertionRange, of: sourceAudioTrack, at: insertionRange.start)
            audioTrackIDs[index] = compositionAudioTrack.trackID
        }

        let item = AVPlayerItem(asset: composition)
        item.audioTimePitchAlgorithm = .spectral

        return PreviewPlayerConfiguration(
            player: AVPlayer(playerItem: item),
            audioTrackIDs: audioTrackIDs
        )
    }
}
