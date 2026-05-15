from .models import Item
from django.http import JsonResponse


def item_list(request):
    if request.method != 'GET':
        return JsonResponse({'detail': 'Method not allowed'}, status=405)

    items = Item.objects.values('id', 'name', 'description', 'price', 'created_at', 'updated_at')
    return JsonResponse(list(items), safe=False)
