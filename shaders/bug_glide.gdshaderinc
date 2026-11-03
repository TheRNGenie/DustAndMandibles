// Glide for the bug MultiMesh batches (LegBatch). A bug updated only a few
// times a second writes its pieces with custom data: rgb = its world velocity
// (m per physics tick), a = the glide-clock tick its glide ends at. Until then
// a piece is drawn (end - now) ticks back along that velocity, so the bug slides
// from where it was drawn to where it really is. Custom data 0 = no glide.
// bug_glide_now is set every frame by BugManager (LegBatch.publish_clock).

global uniform float bug_glide_now;

vec3 bug_glide(vec3 vertex, vec4 custom, mat4 model) {
	float left = custom.w - bug_glide_now;
	if (left > 0.0 && dot(custom.xyz, custom.xyz) > 0.0) {
		// World offset into the instance's own (scaled) space.
		vertex -= inverse(mat3(model)) * (custom.xyz * left);
	}
	return vertex;
}
