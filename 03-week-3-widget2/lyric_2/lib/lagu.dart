class Lagu {
  final String judul;
  final String penyanyi;
  final String lyric;
  final String? coverImagePath; // Optional: Path to the cover image

  const Lagu({
    required this.judul,
    required this.penyanyi,
    required this.lyric,
    this.coverImagePath,
  });

  static const currentSong = Lagu(
    judul: 'Evergreen',
    penyanyi: 'Knuckle Puck',
    lyric: '''
This is where it starts, right here, square one
Head for the door back to the west coast
Setting sail on concrete oceans
Feel the hills roll on engulfed in flames
Where red woods tower over me
Where there's so much more than we think there is to see
I'll lead a life of firsts on foreign soils
Somewhere that I can find the bones of a better man inside
(Somewhere that I can find)
Holding in tightly to the misery will never get me far
It will never get you far
As I exhale this breath of fresh air
I feel the distance tear the space between us
Cause we're always climbing toward the sun
But the cabin pressure gets to me
And there's so much more than we think there is to see
On to barren land and wasted weeks but we won't keep searching
We're fucking helpless
And I feel the staleness in the autumn air, it's not like usual
It's fucking hopeless
I'll lead a life of firsts on foreign soils
Somewhere that I can find the bones of a better man inside
(Somewhere that I can find)
Holding in tightly to the misery will never get me far
It will never get you far
I'll leave this all behind for you when I'm gone
You grew from a seed
Forever strong as a pine tree
Always an evergreen
I'll leave this all behind for you when I'm gone
You grew from a seed
Forever strong as a pine tree
Always an evergreen
I'll leave this all behind for you when I'm gone
You grew from a seed
Forever strong as a pine tree
Always an evergreen
(I'll leave this all behind for you when I'm gone
You grew from a seed
Forever strong as a pine tree
Always an evergreen)
''',
    coverImagePath: 'assets/cover.png',
  );
}