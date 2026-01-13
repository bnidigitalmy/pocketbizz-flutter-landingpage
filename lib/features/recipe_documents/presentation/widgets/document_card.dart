import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/recipe_document.dart';

class DocumentCard extends StatelessWidget {
  final RecipeDocument document;
  final VoidCallback onTap;
  final VoidCallback onFavourite;
  final VoidCallback onDelete;

  const DocumentCard({
    super.key,
    required this.document,
    required this.onTap,
    required this.onFavourite,
    required this.onDelete,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hari ini';
    } else if (difference.inDays == 1) {
      return 'Semalam';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari lalu';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks minggu lalu';
    } else {
      return DateFormat('d MMM yyyy', 'ms_MY').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: document.isFile
                          ? Colors.blue[100]
                          : Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        document.displayIcon,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Title and metadata
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          document.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            if (document.categoryId != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Kategori',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            Text(
                              _formatDate(document.uploadedAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (document.isFavourite)
                              const Icon(
                                Icons.star,
                                size: 14,
                                color: Colors.amber,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Actions menu
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert, size: 20),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(
                              document.isFavourite
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(document.isFavourite
                                ? 'Buang dari Favorit'
                                : 'Tambah ke Favorit'),
                          ],
                        ),
                        onTap: () {
                          Future.delayed(
                            const Duration(milliseconds: 100),
                            onFavourite,
                          );
                        },
                      ),
                      const PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Padam', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                        onTap: null, // Will be handled by onDelete
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'delete') {
                        onDelete();
                      }
                    },
                  ),
                ],
              ),
              // File info (if file)
              if (document.isFile && document.fileSize != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.insert_drive_file,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${document.fileName} • ${document.formattedFileSize}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              // Text preview (if text)
              if (document.isText && document.textContent != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    document.textContent!.length > 80
                        ? '${document.textContent!.substring(0, 80)}...'
                        : document.textContent!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
