RememberMe: The AI-Native Memory Asset Manager
## Inspiration
The inspiration for RememberMe came from a deeply personal fear: the fading of family history. As our loved ones age, their stories—the context behind the old photos in shoeboxes—often disappear with them. Physical albums are fragile, hard to search, and static.
We realized that in the age of AGI, we shouldn't just store photos; we should manage memories as valuable assets. We wanted to build a bridge between the past and the future, allowing users not just to recall what happened, but to reconstruct scenes that never were—like seeing a grandfather holding his great-grandchild, even if they never met in this timeline.

## What it does
RememberMe is a comprehensive Memory Asset Management Platform built on three core pillars:
Memory Stream (Data Ingestion): A smart grid that transforms chaotic photo dumps into structured "Story Collections," acting as the single source of truth for family history.
emory Chat (Temporal RAG): A conversational agent that allows users to "talk" to their albums. You can ask, "Show me photos of Mom in the 90s," and the AI retrieves visual evidence alongside text answers.
Dream Director (Multimodal Fusion): The flagship feature. It allows users to fuse visual features from old photos with new scenarios (e.g., "My younger mom having coffee with me now"), using AI to bridge time and space.

## How we built it
We built the frontend using Flutter for a smooth, cross-platform experience. The core intelligence is powered by Google's latest generative AI models.
Instead of complex training, we designed a "Two-Stage AI Pipeline":
1. The "Dream Director" Engine
To ensure the generated characters actually look like the user's family members, we used a creative workflow:
Stage 1: Visual Analysis with Gemini 3 Flash Preview We treat Gemini not just as a chatbot, but as a "Forensic Artist." When a user selects a reference photo (e.g., of their grandmother), we ask Gemini to analyze the image pixel-by-pixel. It extracts a highly detailed text description of her physical traits—focusing on eye shape, hair texture, and clothing patterns—rather than just a general description.
Stage 2: Image Synthesis with Imagen 4.0 We take those specific physical traits and combine them with the user's wish (e.g., "sitting in a garden"). This creates a "Master Prompt" that is sent to Imagen 4.0 (imagen-4.0-generate-001). This allows us to generate photorealistic images that maintain the identity of the original person without needing to train a custom model.
2. Memory Chat with Gemini 3 Flash
We leveraged the massive context window of Gemini 3 Flash Preview to process multiple image bytes directly within the chat context. This allows the model to answer questions based on actual visual data rather than just metadata tags, providing a truly "multimodal" experience where the AI "sees" your memories.

## Challenges we faced
Identity Consistency vs. Hallucination: Initially, when we asked the AI to "generate a photo of my mom," it created a generic person. We learned that generic prompts yield generic results. We overcame this by implementing the "Forensic Analysis" method described above—forcing Gemini to be extremely specific about facial features before generating the image.
Flutter & Async State: Managing the state between the Chat, Story Grid, and the complex image generation process was tricky. We solved this by using a centralized MemoryModel and careful state management to ensure the UI updates instantly when a new "Wish" is granted.

## Accomplishments that we're proud of
1. From Zero to App in 30 Days
Just one month ago, I knew absolutely nothing about AI coding. I couldn't even read basic technical terminology, let alone write Dart code or integrate APIs. My motivation was simple and personal: I wanted to preserve the stories my grandfather tells every time he looks at his old photos. With Gemini as my guide, I started from scratch. Even though RememberMe is still in its early stages, I am amazed at the result and the capabilities of Gemini. Regardless of the hackathon outcome, I am committed to continuing this project until it is robust enough for my family to use every day.
2. A "Solo" Team with an AI Partner
I entered this hackathon as a single human participant, but I never felt alone. My teammate was Gemini. It guided me through the entire process—from brainstorming features to writing complex asynchronous code, and even helping me debug errors I didn't understand. Gemini didn't just generate code; it taught me how to think like a developer. This project proves that with the right AI partner, anyone can turn a heartwarming idea into a working reality.

## What we learned
Prompt Engineering is Logic: I learned that communicating with AI is less about writing sentences and more about designing logic flows. Structure matters more than length.
The Speed of Flash: Switching to Gemini 3 Flash significantly reduced the waiting time in our visual analysis pipeline, making the "Dream Director" feel almost instantaneous.
The Power of Multimodality: This project proved that beginners can build powerful "Memory RAG" systems without complex vector databases, simply by leveraging Gemini's native understanding of images and text.

## What's next for RememberMe
Timeline: A linear visualization of life's major milestones, ensuring no legacy is forgotten.
Voice Mode: Integrating Gemini Live to allow the elderly to "tell" their stories to the app purely by voice.
Video Generation: Using Google Veo to animate static memories into short clips.
Physical Printing: Automatically generating "Yearbooks" from the curated memories.
