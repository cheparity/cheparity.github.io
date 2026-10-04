type TaggedPost = {
	id: string;
	data: { title: string; pubDate: Date; tags?: string[] };
};

export function relatedPostsFor(post: TaggedPost, candidates: TaggedPost[]) {
	const ownTags = post.data.tags ?? [];
	if (ownTags.length === 0) return [];

	return candidates
		.filter((candidate) => candidate.id !== post.id)
		.map((candidate) => ({
			id: candidate.id,
			title: candidate.data.title,
			tags: (candidate.data.tags ?? []).filter((tag) => ownTags.includes(tag)),
			pubDate: candidate.data.pubDate.valueOf(),
		}))
		.filter((candidate) => candidate.tags.length > 0)
		.sort((a, b) => b.tags.length - a.tags.length || b.pubDate - a.pubDate)
		.slice(0, 3);
}
