FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY syncfusion_api/ShamsPdfApi.csproj syncfusion_api/
RUN dotnet restore syncfusion_api/ShamsPdfApi.csproj

COPY syncfusion_api/ syncfusion_api/
RUN dotnet publish syncfusion_api/ShamsPdfApi.csproj -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app

COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://0.0.0.0:10000
EXPOSE 10000

ENTRYPOINT ["dotnet", "ShamsPdfApi.dll"]