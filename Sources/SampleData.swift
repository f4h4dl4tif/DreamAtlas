import Foundation

/// Sample journal used only by the --snapshot developer mode.
enum SampleData {
    static func make() -> JournalData {
        let seeds: [(String, String, [String], [String], Int, Int, Bool, Bool)] = [
            ("The house by the lake", "I was back in my grandmother's house, but it was standing at the edge of a huge lake. Water kept rising through the floorboards and nobody else seemed to notice. I found a door I'd never seen before that opened onto a garden full of lanterns.", ["Wonder", "Nostalgia", "Calm"], ["Water", "Home", "Family"], 5, 1, false, true),
            ("Late for the train", "Running through a station that kept changing shape. My ticket turned into a feather. The train left without me and I realised I'd forgotten my shoes.", ["Anxiety", "Confusion"], ["Late", "Travel", "Losing something"], 4, -1, false, false),
            ("Flying over the city", "I realised I was dreaming when the street lights turned into stars. I lifted off and flew over the rooftops, the river shining below me.", ["Joy", "Excitement", "Wonder"], ["Flying", "City", "Water"], 5, 2, true, false),
            ("Exam in the old school", "Sitting an exam in my old school hall, but the questions were about the ocean. My pen ran out of ink. A teacher I didn't recognise kept smiling at me.", ["Anxiety", "Curiosity"], ["Exams", "School", "Water"], 3, -1, false, true),
            ("Dinner with friends", "A long table in a forest clearing. Friends from different parts of my life were all there together, passing bread and laughing. A fox sat quietly by the fire.", ["Love", "Joy", "Calm"], ["Friends", "Food", "Nature", "Animals"], 4, 2, false, false),
            ("Lost in the hotel", "Corridors that went on forever, every door with the same number. I was looking for my room and my phone had no signal. Eventually I found a staircase going down to the sea.", ["Confusion", "Anxiety"], ["Being lost", "Travel", "Water"], 3, -1, false, true),
            ("The dog that could talk", "Our childhood dog came back and told me, very seriously, that the garden needed watering. I woke up laughing.", ["Joy", "Nostalgia"], ["Animals", "Childhood", "Home"], 4, 2, false, false),
            ("Chased through the market", "Something I couldn't see was following me through a night market. I hid under a stall selling glass birds. When I looked back the street was empty.", ["Fear", "Anxiety"], ["Being chased", "City", "Darkness"], 4, -2, false, false),
            ("Swimming with whales", "Deep blue water, completely calm. Two whales swam beside me and I could breathe underwater without trying.", ["Calm", "Wonder", "Relief"], ["Water", "Animals", "Nature"], 5, 2, true, false),
            ("Moving house again", "Packing boxes in a house that kept growing new rooms. My sister was there telling me which things to keep. I found a box of old letters.", ["Nostalgia", "Sadness"], ["Home", "Family", "Losing something"], 3, 0, false, true),
            ("Bus to nowhere", "A night bus driving through fields of sunflowers that glowed in the dark. The driver was a friend from work.", ["Curiosity", "Calm"], ["Vehicles", "Travel", "Work"], 3, 1, false, false),
            ("Falling from the tower", "Standing on top of a tall tower in the wind, then falling slowly. Just before landing I started to float instead.", ["Fear", "Relief"], ["Falling", "Flying"], 4, 0, false, true),
            ("Birthday in the garden", "A surprise party for me in my grandmother's garden. Everyone was wearing white. The cake was shaped like the lake house.", ["Joy", "Love"], ["Celebration", "Family", "Home"], 4, 2, false, false),
            ("Teeth falling out", "Talking at work and my teeth started crumbling. Nobody reacted. I tried to hide it with my hand.", ["Anxiety", "Shame"], ["Teeth", "Work"], 3, -2, false, true),
            ("Lighthouse at dawn", "Climbing a lighthouse staircase that spiralled up forever. At the top the sun was rising over the sea and I felt completely at peace.", ["Calm", "Wonder"], ["Water", "Nature"], 5, 2, false, false),
            ("Train through the mountains", "On a train again, this time on time. Snowy mountains, warm tea, a stranger reading my diary out loud.", ["Curiosity", "Confusion"], ["Travel", "Vehicles", "Strangers"], 3, 0, false, false),
            ("The flooded library", "Books floating in a library full of water. I was trying to save one particular book but couldn't remember its title.", ["Sadness", "Curiosity"], ["Water", "Losing something"], 4, -1, false, false),
            ("Night swim", "Swimming in the lake from the house dream. The water was warm and full of tiny lights.", ["Calm", "Joy"], ["Water", "Home", "Nature"], 4, 1, true, true),
        ]
        let cal = Calendar.current
        let offsets = [1, 3, 6, 9, 13, 16, 20, 25, 29, 34, 40, 47, 55, 63, 72, 80, 96, 110]
        var data = JournalData()
        for (i, s) in seeds.enumerated() {
            var d = Dream()
            d.date = cal.date(byAdding: .day, value: -offsets[i % offsets.count], to: Date().day)!
            d.title = s.0; d.text = s.1; d.emotions = s.2; d.themes = s.3
            d.vividness = s.4; d.wakingMood = s.5; d.lucid = s.6; d.recurring = s.7
            d.created = d.date.addingTimeInterval(7 * 3600); d.modified = d.created
            data.dreams.append(d)
        }
        return data
    }
}
